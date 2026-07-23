import { Module } from '@nestjs/common';
import { EmailService } from './channels/email.service';
import { PushService } from './channels/push.service';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService, EmailService, PushService],
  exports: [NotificationsService, EmailService],
})
export class NotificationsModule {}
