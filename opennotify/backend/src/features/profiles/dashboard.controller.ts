import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { BillingService } from '../billing/billing.service';

@ApiTags('dashboard')
@ApiBearerAuth()
@Controller('dashboard')
export class DashboardController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly billing: BillingService,
  ) {}

  @Get('stats')
  @ApiOperation({ summary: 'Aggregate stats for the dashboard cards' })
  async stats(@CurrentUser() user: AuthUser) {
    const [activeProfiles, changesDetected, notificationsSent, subscription, recentChanges] =
      await Promise.all([
        this.prisma.monitoredProfile.count({
          where: { userId: user.id, monitoringEnabled: true },
        }),
        this.prisma.statusChange.count({
          where: { profile: { userId: user.id } },
        }),
        this.prisma.notification.count({ where: { userId: user.id } }),
        this.billing.getSubscription(user.id),
        this.prisma.statusChange.findMany({
          where: { profile: { userId: user.id } },
          orderBy: { createdAt: 'desc' },
          take: 10,
          include: { profile: { select: { username: true } } },
        }),
      ]);
    return { activeProfiles, changesDetected, notificationsSent, subscription, recentChanges };
  }
}
