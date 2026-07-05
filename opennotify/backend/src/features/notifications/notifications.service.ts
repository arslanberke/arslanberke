import { Injectable } from '@nestjs/common';
import { NotificationChannel } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { EmailService } from './channels/email.service';
import { PushService } from './channels/push.service';

export interface NotificationContent {
  title: string;
  body: string;
}

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly email: EmailService,
    private readonly push: PushService,
  ) {}

  async notifyUser(userId: string, content: NotificationContent): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) return;

    if (user.inAppNotifications) {
      await this.prisma.notification.create({
        data: { userId, channel: NotificationChannel.IN_APP, ...content },
      });
    }
    if (user.emailNotifications) {
      await this.email.send(user.email, content.title, content.body);
      await this.prisma.notification.create({
        data: { userId, channel: NotificationChannel.EMAIL, ...content },
      });
    }
    if (user.pushNotifications) {
      await this.push.sendToUser(userId, content.title, content.body);
      await this.prisma.notification.create({
        data: { userId, channel: NotificationChannel.PUSH, ...content },
      });
    }
  }

  list(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async markRead(userId: string, id: string) {
    await this.prisma.notification.updateMany({
      where: { id, userId, readAt: null },
      data: { readAt: new Date() },
    });
  }

  async markAllRead(userId: string) {
    await this.prisma.notification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
  }
}
