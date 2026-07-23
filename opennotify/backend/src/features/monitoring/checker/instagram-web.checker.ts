import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ProfileStatus } from '@prisma/client';
import { ProfileChecker, ProfileCheckResult } from './profile-checker.interface';

/**
 * Resolves visibility from Instagram's public web_profile_info endpoint — the
 * same JSON the website itself requests when rendering a profile page. No
 * login and no third-party service is required.
 *
 * Note: this reads Instagram's public web API directly. Instagram rate-limits
 * by IP and its endpoints can change, so `UNKNOWN` is returned on any error
 * (network, rate limit, unexpected shape) instead of throwing. For higher
 * volume or stronger guarantees, implement ProfileChecker against a licensed
 * data provider and select it via PROFILE_CHECKER_PROVIDER.
 */
@Injectable()
export class InstagramWebChecker implements ProfileChecker {
  readonly name = 'instagram_web';
  private readonly logger = new Logger(InstagramWebChecker.name);
  private readonly appId: string;
  private readonly userAgent: string;

  constructor(config: ConfigService) {
    this.appId = config.get('INSTAGRAM_APP_ID', '936619743392459');
    this.userAgent = config.get(
      'INSTAGRAM_USER_AGENT',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
    );
  }

  async check(username: string): Promise<ProfileCheckResult> {
    const checkedAt = new Date();
    const handle = username.trim().replace(/^@/, '');
    const url = `https://www.instagram.com/api/v1/users/web_profile_info/?username=${encodeURIComponent(handle)}`;

    // Retry a couple of times with backoff to ride out transient IP rate limits.
    const maxAttempts = 3;
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 10_000);
        const res = await fetch(url, {
          headers: {
            'x-ig-app-id': this.appId,
            'User-Agent': this.userAgent,
            Accept: 'application/json',
          },
          signal: controller.signal,
        }).finally(() => clearTimeout(timeout));

        if (res.status === 404) {
          // Account does not exist (or was removed) — not the same as private.
          return { status: ProfileStatus.UNKNOWN, checkedAt };
        }
        if (res.status === 429 && attempt < maxAttempts) {
          await this.sleep(1000 * attempt + Math.floor(Math.random() * 500));
          continue;
        }
        if (!res.ok) {
          this.logger.warn(`Instagram returned ${res.status} for @${handle}`);
          return { status: ProfileStatus.UNKNOWN, checkedAt };
        }

        const body = (await res.json()) as {
          data?: { user?: { is_private?: boolean } | null };
        };
        const user = body.data?.user;
        if (!user || typeof user.is_private !== 'boolean') {
          return { status: ProfileStatus.UNKNOWN, checkedAt };
        }

        return {
          status: user.is_private ? ProfileStatus.PRIVATE : ProfileStatus.PUBLIC,
          checkedAt,
        };
      } catch (error) {
        if (attempt >= maxAttempts) {
          this.logger.warn(
            `Failed to check @${handle}: ${error instanceof Error ? error.message : String(error)}`,
          );
          return { status: ProfileStatus.UNKNOWN, checkedAt };
        }
        await this.sleep(1000 * attempt);
      }
    }

    return { status: ProfileStatus.UNKNOWN, checkedAt };
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
