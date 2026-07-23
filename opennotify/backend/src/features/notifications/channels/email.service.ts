import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Email delivery abstraction. The "console" provider logs emails, which is
 * safe for development. Swap in an SMTP/SES/Resend implementation by
 * extending this service — callers depend only on `send`.
 */
@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);

  constructor(private readonly config: ConfigService) {}

  async send(to: string, subject: string, body: string): Promise<void> {
    const provider = this.config.get('EMAIL_PROVIDER', 'console');
    if (provider === 'console') {
      this.logger.log(`[email -> ${to}] ${subject}: ${body}`);
      return;
    }
    this.logger.warn(`Email provider "${provider}" not implemented; email dropped`);
  }
}
