import { Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { MonitoringModule } from '../monitoring/monitoring.module';
import { DashboardController } from './dashboard.controller';
import { ProfilesController } from './profiles.controller';
import { ProfilesRepository } from './profiles.repository';
import { ProfilesService } from './profiles.service';

@Module({
  imports: [MonitoringModule, BillingModule],
  controllers: [ProfilesController, DashboardController],
  providers: [ProfilesService, ProfilesRepository],
  exports: [ProfilesService],
})
export class ProfilesModule {}
