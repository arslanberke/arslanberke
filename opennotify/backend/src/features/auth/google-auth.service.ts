import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OAuth2Client } from 'google-auth-library';

export interface GoogleProfile {
  googleId: string;
  email: string;
  name: string;
  avatarUrl?: string;
}

@Injectable()
export class GoogleAuthService {
  private readonly client: OAuth2Client;

  constructor(private readonly config: ConfigService) {
    this.client = new OAuth2Client(this.config.get('GOOGLE_CLIENT_ID'));
  }

  async verify(idToken: string): Promise<GoogleProfile> {
    try {
      const ticket = await this.client.verifyIdToken({
        idToken,
        audience: this.config.get('GOOGLE_CLIENT_ID'),
      });
      const payload = ticket.getPayload();
      if (!payload?.sub || !payload.email) throw new Error('Missing claims');
      return {
        googleId: payload.sub,
        email: payload.email,
        name: payload.name ?? payload.email,
        avatarUrl: payload.picture,
      };
    } catch {
      throw new UnauthorizedException('Invalid Google token');
    }
  }
}
