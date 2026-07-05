import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InstagramWebChecker } from './instagram-web.checker';
import { MockProfileChecker } from './mock-profile.checker';
import { PROFILE_CHECKER, ProfileChecker } from './profile-checker.interface';

/**
 * Registry of available checker providers. Add new implementations here and
 * select them via the PROFILE_CHECKER_PROVIDER env var.
 */
@Module({
  providers: [
    MockProfileChecker,
    InstagramWebChecker,
    {
      provide: PROFILE_CHECKER,
      inject: [ConfigService, MockProfileChecker, InstagramWebChecker],
      useFactory: (
        config: ConfigService,
        mock: MockProfileChecker,
        instagramWeb: InstagramWebChecker,
      ): ProfileChecker => {
        const provider = config.get('PROFILE_CHECKER_PROVIDER', 'mock');
        const registry: Record<string, ProfileChecker> = {
          mock,
          instagram_web: instagramWeb,
        };
        const checker = registry[provider];
        if (!checker) {
          throw new Error(`Unknown PROFILE_CHECKER_PROVIDER "${provider}"`);
        }
        return checker;
      },
    },
  ],
  exports: [PROFILE_CHECKER],
})
export class CheckerModule {}
