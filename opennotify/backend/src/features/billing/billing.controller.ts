import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiTags } from '@nestjs/swagger';
import { Plan } from '@prisma/client';
import { IsEnum } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { BillingService } from './billing.service';

class CheckoutDto {
  @ApiProperty({ enum: Plan })
  @IsEnum(Plan)
  plan: Plan;
}

@ApiTags('billing')
@Controller('billing')
export class BillingController {
  constructor(private readonly billing: BillingService) {}

  @Public()
  @Get('plans')
  @ApiOperation({ summary: 'List available plans' })
  plans() {
    return this.billing.listPlans();
  }

  @ApiBearerAuth()
  @Get('subscription')
  @ApiOperation({ summary: 'Get current subscription' })
  subscription(@CurrentUser() user: AuthUser) {
    return this.billing.getSubscription(user.id);
  }

  @ApiBearerAuth()
  @Post('checkout')
  @ApiOperation({ summary: 'Create a Stripe checkout session (not yet configured)' })
  checkout(@CurrentUser() user: AuthUser, @Body() dto: CheckoutDto) {
    return this.billing.createCheckoutSession(user.id, dto.plan);
  }
}
