import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../../infra/prisma/prisma.service';

/**
 * Push notification abstraction. Device tokens are stored per user; wire an
 * FCM/APNs client into `sendToUser` to enable real delivery.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

  constructor(private readonly prisma: PrismaService) {}

  async sendToUser(userId: string, title: string, body: string): Promise<void> {
    const devices = await this.prisma.pushDevice.findMany({ where: { userId } });
    for (const device of devices) {
      this.logger.log(`[push -> ${device.platform}:${device.token.slice(0, 8)}…] ${title}: ${body}`);
    }
  }
}
