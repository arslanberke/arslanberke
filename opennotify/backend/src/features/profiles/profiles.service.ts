import { InjectQueue } from '@nestjs/bullmq';
import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Queue } from 'bullmq';
import { BillingService } from '../billing/billing.service';
import {
  CheckProfileJob,
  MONITORING_QUEUE,
} from '../monitoring/monitoring.constants';
import { ProfilesRepository } from './profiles.repository';

@Injectable()
export class ProfilesService {
  constructor(
    private readonly profiles: ProfilesRepository,
    private readonly billing: BillingService,
    @InjectQueue(MONITORING_QUEUE) private readonly queue: Queue<CheckProfileJob>,
  ) {}

  list(userId: string, search?: string) {
    return this.profiles.findAllByUser(userId, search);
  }

  async add(userId: string, username: string) {
    const normalized = username.toLowerCase().replace(/^@/, '');
    const limit = await this.billing.getProfileLimit(userId);
    const count = await this.profiles.countByUser(userId);
    if (limit !== null && count >= limit) {
      throw new ForbiddenException(
        `Your plan allows up to ${limit} monitored profiles. Upgrade to add more.`,
      );
    }
    const existing = await this.profiles.findAllByUser(userId, normalized);
    if (existing.some((p) => p.username === normalized)) {
      throw new BadRequestException('You are already monitoring this username');
    }
    const profile = await this.profiles.create(userId, normalized);
    await this.queue.add(
      'check',
      { profileId: profile.id },
      { removeOnComplete: true, removeOnFail: 100 },
    );
    return profile;
  }

  async remove(userId: string, id: string) {
    await this.getOwned(userId, id);
    await this.profiles.delete(id);
  }

  async pause(userId: string, id: string) {
    await this.getOwned(userId, id);
    return this.profiles.setMonitoring(id, false);
  }

  async resume(userId: string, id: string) {
    await this.getOwned(userId, id);
    return this.profiles.setMonitoring(id, true);
  }

  async history(userId: string, id: string) {
    await this.getOwned(userId, id);
    return this.profiles.history(id);
  }

  async getOwned(userId: string, id: string) {
    const profile = await this.profiles.findByIdForUser(id, userId);
    if (!profile) throw new NotFoundException('Profile not found');
    return profile;
  }
}
