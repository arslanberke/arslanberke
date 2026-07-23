import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { CheckerModule } from './checker/checker.module';
import { MONITORING_QUEUE } from './monitoring.constants';
import { MonitoringProcessor } from './monitoring.processor';
import { MonitoringScheduler } from './monitoring.scheduler';
import { MonitoringService } from './monitoring.service';

@Module({
  imports: [
    BullModule.registerQueue({ name: MONITORING_QUEUE }),
    CheckerModule,
    NotificationsModule,
  ],
  providers: [MonitoringService, MonitoringProcessor, MonitoringScheduler],
  exports: [MonitoringService, BullModule],
})
export class MonitoringModule {}
