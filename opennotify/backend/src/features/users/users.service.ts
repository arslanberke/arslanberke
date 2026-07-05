import { Injectable, NotFoundException } from '@nestjs/common';
import { User } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { UpdateSettingsDto } from './dto/update-settings.dto';
import { UsersRepository } from './users.repository';

export type SafeUser = Omit<User, 'passwordHash'>;

const toSafe = (user: User): SafeUser => {
  const { passwordHash: _passwordHash, ...safe } = user;
  return safe;
};

@Injectable()
export class UsersService {
  constructor(
    private readonly users: UsersRepository,
    private readonly prisma: PrismaService,
  ) {}

  async getMe(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: { subscription: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return { ...toSafe(user), subscription: user.subscription };
  }

  async updateSettings(id: string, dto: UpdateSettingsDto): Promise<SafeUser> {
    return toSafe(await this.users.update(id, dto));
  }

  async deleteAccount(id: string): Promise<void> {
    await this.users.delete(id);
  }

  async registerPushDevice(userId: string, token: string, platform: string) {
    return this.prisma.pushDevice.upsert({
      where: { token },
      update: { userId, platform },
      create: { userId, token, platform },
    });
  }
}
