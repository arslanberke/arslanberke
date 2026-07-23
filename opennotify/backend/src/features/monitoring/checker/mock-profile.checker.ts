import { Injectable } from '@nestjs/common';
import { ProfileStatus } from '@prisma/client';
import { createHash } from 'crypto';
import { ProfileChecker, ProfileCheckResult } from './profile-checker.interface';

/**
 * Deterministic simulation of profile visibility. The status for a username
 * is stable within a time window and occasionally flips, so change detection,
 * notifications, and history can be exercised end-to-end without touching
 * any external service.
 */
@Injectable()
export class MockProfileChecker implements ProfileChecker {
  readonly name = 'mock';

  async check(username: string): Promise<ProfileCheckResult> {
    const window = Math.floor(Date.now() / (1000 * 60 * 30)); // 30-minute windows
    const digest = createHash('sha256').update(`${username}:${window}`).digest();
    const value = digest[0];
    const status: ProfileStatus =
      value < 8 ? ProfileStatus.UNKNOWN : value % 2 === 0 ? ProfileStatus.PUBLIC : ProfileStatus.PRIVATE;
    return { status, checkedAt: new Date() };
  }
}
