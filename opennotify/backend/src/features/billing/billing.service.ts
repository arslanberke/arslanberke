import { Injectable, NotImplementedException } from '@nestjs/common';
import { Plan } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { getPlan, PLANS } from './plans';

@Injectable()
export class BillingService {
  constructor(private readonly prisma: PrismaService) {}

  listPlans() {
    return PLANS;
  }

  async getSubscription(userId: string) {
    const subscription = await this.prisma.subscription.upsert({
      where: { userId },
      update: {},
      create: { userId },
    });
    return { ...subscription, planDetails: getPlan(subscription.plan) };
  }

  async getProfileLimit(userId: string): Promise<number | null> {
    const subscription = await this.getSubscription(userId);
    return getPlan(subscription.plan).profileLimit;
  }

  /**
   * Stripe-ready checkout entry point. When Stripe is integrated this will
   * create a Checkout Session for the plan's stripePriceId and return its URL.
   */
  createCheckoutSession(_userId: string, _plan: Plan): Promise<{ url: string }> {
    throw new NotImplementedException('Stripe checkout is not configured yet');
  }
}
