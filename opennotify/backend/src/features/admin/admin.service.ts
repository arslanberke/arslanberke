import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../infra/prisma/prisma.service';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  listUsers(search?: string) {
    return this.prisma.user.findMany({
      where: search
        ? {
            OR: [
              { email: { contains: search, mode: 'insensitive' } },
              { name: { contains: search, mode: 'insensitive' } },
            ],
          }
        : undefined,
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        isDisabled: true,
        emailVerifiedAt: true,
        createdAt: true,
        subscription: { select: { plan: true, status: true } },
        _count: { select: { monitoredProfiles: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  listProfiles() {
    return this.prisma.monitoredProfile.findMany({
      include: { user: { select: { email: true, name: true } } },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  async setUserDisabled(userId: string, disabled: boolean, adminId: string) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { isDisabled: disabled },
    });
    await this.prisma.auditLog.create({
      data: {
        userId: adminId,
        action: disabled ? 'admin.user.disable' : 'admin.user.enable',
        metadata: { targetUserId: userId },
      },
    });
    return { id: user.id, isDisabled: user.isDisabled };
  }

  async stats() {
    const [users, profiles, changes, notifications] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.monitoredProfile.count(),
      this.prisma.statusChange.count(),
      this.prisma.notification.count(),
    ]);
    return { users, profiles, changes, notifications };
  }

  logs() {
    return this.prisma.auditLog.findMany({
      include: { user: { select: { email: true } } },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }
}
