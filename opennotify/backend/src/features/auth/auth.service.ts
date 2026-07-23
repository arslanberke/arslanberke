import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { User } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { createHash, randomBytes } from 'crypto';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { EmailService } from '../notifications/channels/email.service';
import { UsersRepository } from '../users/users.repository';
import { GoogleAuthService } from './google-auth.service';

export interface JwtPayload {
  sub: string;
  email: string;
  role: 'USER' | 'ADMIN';
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersRepository,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly email: EmailService,
    private readonly google: GoogleAuthService,
  ) {}

  async register(email: string, password: string, name: string) {
    const existing = await this.users.findByEmail(email);
    if (existing) throw new BadRequestException('Email already in use');

    const user = await this.users.create({
      email,
      name,
      passwordHash: await bcrypt.hash(password, 10),
      subscription: { create: {} },
    });
    await this.sendVerificationEmail(user);
    return this.issueTokens(user);
  }

  async login(email: string, password: string) {
    const user = await this.users.findByEmail(email);
    if (!user?.passwordHash || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid credentials');
    }
    this.assertEnabled(user);
    return this.issueTokens(user);
  }

  async loginWithGoogle(idToken: string) {
    const profile = await this.google.verify(idToken);
    let user = await this.prisma.user.findUnique({ where: { googleId: profile.googleId } });
    if (!user) {
      const byEmail = await this.users.findByEmail(profile.email);
      user = byEmail
        ? await this.prisma.user.update({
            where: { id: byEmail.id },
            data: { googleId: profile.googleId, emailVerifiedAt: byEmail.emailVerifiedAt ?? new Date() },
          })
        : await this.users.create({
            email: profile.email,
            name: profile.name,
            googleId: profile.googleId,
            avatarUrl: profile.avatarUrl,
            emailVerifiedAt: new Date(),
            subscription: { create: {} },
          });
    }
    this.assertEnabled(user);
    return this.issueTokens(user);
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    const tokenHash = sha256(refreshToken);
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });
    if (!stored || stored.revokedAt || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid refresh token');
    }
    this.assertEnabled(stored.user);
    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });
    return this.issueTokens(stored.user);
  }

  async logout(refreshToken: string) {
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash: sha256(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async forgotPassword(email: string) {
    const user = await this.users.findByEmail(email);
    if (!user) return; // do not leak account existence
    const token = await this.createVerificationToken(user.id, 'PASSWORD_RESET', 60);
    const url = `${this.config.get('FRONTEND_URL')}/reset-password?token=${token}`;
    await this.email.send(user.email, 'Reset your OpenNotify password', `Reset link: ${url}`);
  }

  async resetPassword(token: string, password: string) {
    const record = await this.consumeVerificationToken(token, 'PASSWORD_RESET');
    await this.prisma.user.update({
      where: { id: record.userId },
      data: { passwordHash: await bcrypt.hash(password, 10) },
    });
    await this.prisma.refreshToken.updateMany({
      where: { userId: record.userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async verifyEmail(token: string) {
    const record = await this.consumeVerificationToken(token, 'EMAIL_VERIFY');
    await this.prisma.user.update({
      where: { id: record.userId },
      data: { emailVerifiedAt: new Date() },
    });
  }

  async resendVerification(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    if (user.emailVerifiedAt) throw new BadRequestException('Email already verified');
    await this.sendVerificationEmail(user);
  }

  private assertEnabled(user: User) {
    if (user.isDisabled) throw new ForbiddenException('Account disabled');
  }

  private async sendVerificationEmail(user: User) {
    const token = await this.createVerificationToken(user.id, 'EMAIL_VERIFY', 60 * 24);
    const url = `${this.config.get('FRONTEND_URL')}/verify-email?token=${token}`;
    await this.email.send(user.email, 'Verify your OpenNotify email', `Verify link: ${url}`);
  }

  private async createVerificationToken(userId: string, type: string, ttlMinutes: number) {
    const token = randomBytes(32).toString('hex');
    await this.prisma.verificationToken.create({
      data: {
        userId,
        type,
        tokenHash: sha256(token),
        expiresAt: new Date(Date.now() + ttlMinutes * 60_000),
      },
    });
    return token;
  }

  private async consumeVerificationToken(token: string, type: string) {
    const record = await this.prisma.verificationToken.findUnique({
      where: { tokenHash: sha256(token) },
    });
    if (!record || record.type !== type || record.usedAt || record.expiresAt < new Date()) {
      throw new BadRequestException('Invalid or expired token');
    }
    await this.prisma.verificationToken.update({
      where: { id: record.id },
      data: { usedAt: new Date() },
    });
    return record;
  }

  private async issueTokens(user: User): Promise<TokenPair> {
    const payload: JwtPayload = { sub: user.id, email: user.email, role: user.role };
    const accessToken = await this.jwt.signAsync(payload, {
      secret: this.config.getOrThrow('JWT_ACCESS_SECRET'),
      expiresIn: this.config.get('JWT_ACCESS_TTL', '900s'),
    });
    const refreshToken = randomBytes(48).toString('hex');
    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: sha256(refreshToken),
        expiresAt: new Date(Date.now() + 30 * 86_400_000),
      },
    });
    return { accessToken, refreshToken };
  }
}
