import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { CheckProfileJob, MONITORING_QUEUE } from './monitoring.constants';
import { MonitoringService } from './monitoring.service';

@Processor(MONITORING_QUEUE, { concurrency: 5 })
export class MonitoringProcessor extends WorkerHost {
  constructor(private readonly monitoring: MonitoringService) {
    super();
  }

  async process(job: Job<CheckProfileJob>): Promise<void> {
    await this.monitoring.checkProfile(job.data.profileId);
  }
}
