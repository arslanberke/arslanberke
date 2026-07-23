import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { Queue } from 'bullmq';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { CheckProfileJob, MONITORING_QUEUE } from './monitoring.constants';

@Injectable()
export class MonitoringScheduler {
  private readonly logger = new Logger(MonitoringScheduler.name);

  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue(MONITORING_QUEUE) private readonly queue: Queue<CheckProfileJob>,
  ) {}

  @Cron(CronExpression.EVERY_10_MINUTES)
  async enqueueChecks(): Promise<void> {
    const intervalMinutes = parseInt(process.env.CHECK_INTERVAL_MINUTES ?? '15', 10);
    const staleBefore = new Date(Date.now() - intervalMinutes * 60_000);

    const profiles = await this.prisma.monitoredProfile.findMany({
      where: {
        monitoringEnabled: true,
        OR: [{ lastCheckedAt: null }, { lastCheckedAt: { lt: staleBefore } }],
      },
      select: { id: true },
      take: 1000,
    });

    if (profiles.length === 0) return;
    await this.queue.addBulk(
      profiles.map((p) => ({
        name: 'check',
        data: { profileId: p.id },
        opts: { removeOnComplete: true, removeOnFail: 100 },
      })),
    );
    this.logger.log(`Enqueued ${profiles.length} profile checks`);
  }
}
