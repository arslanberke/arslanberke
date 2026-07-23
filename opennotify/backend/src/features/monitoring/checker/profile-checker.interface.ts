import { ProfileStatus } from '@prisma/client';

export interface ProfileCheckResult {
  status: ProfileStatus;
  checkedAt: Date;
}

/**
 * Abstraction over how a profile's visibility is determined.
 *
 * The default implementation is a safe simulation (MockProfileChecker).
 * To go to production, implement this interface against a licensed data
 * provider or an official API and register it in CheckerModule — no other
 * code needs to change.
 */
export interface ProfileChecker {
  readonly name: string;
  check(username: string): Promise<ProfileCheckResult>;
}

export const PROFILE_CHECKER = Symbol('PROFILE_CHECKER');
