import { Inject, Injectable, Logger } from '@nestjs/common';
import { ProfileStatus } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import {
  PROFILE_CHECKER,
  ProfileChecker,
} from './checker/profile-checker.interface';

@Injectable()
export class MonitoringService {
  private readonly logger = new Logger(MonitoringService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    @Inject(PROFILE_CHECKER) private readonly checker: ProfileChecker,
  ) {}

  async checkProfile(profileId: string): Promise<void> {
    const profile = await this.prisma.monitoredProfile.findUnique({
      where: { id: profileId },
    });
    if (!profile || !profile.monitoringEnabled) return;

    const result = await this.checker.check(profile.username);
    const changed =
      result.status !== profile.currentStatus &&
      result.status !== ProfileStatus.UNKNOWN;

    await this.prisma.monitoredProfile.update({
      where: { id: profile.id },
      data: {
        lastCheckedAt: result.checkedAt,
        ...(changed && { currentStatus: result.status, lastChangedAt: result.checkedAt }),
      },
    });

    if (changed) {
      await this.prisma.statusChange.create({
        data: {
          profileId: profile.id,
          oldStatus: profile.currentStatus,
          newStatus: result.status,
        },
      });
      const verb = result.status === ProfileStatus.PUBLIC ? 'public' : 'private';
      await this.notifications.notifyUser(profile.userId, {
        title: 'Profile status changed',
        body: `@${profile.username} became ${verb}.`,
      });
      this.logger.log(
        `Status change for @${profile.username}: ${profile.currentStatus} -> ${result.status}`,
      );
    }
  }
}
