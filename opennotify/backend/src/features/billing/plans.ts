import { Plan } from '@prisma/client';

export interface PlanDefinition {
  id: Plan;
  name: string;
  priceMonthlyUsd: number;
  profileLimit: number | null; // null = unlimited
  features: string[];
  /** Filled in when Stripe is integrated. */
  stripePriceId: string | null;
}

export const PLANS: PlanDefinition[] = [
  {
    id: Plan.FREE,
    name: 'Free',
    priceMonthlyUsd: 0,
    profileLimit: 5,
    features: ['5 monitored profiles', 'Email notifications', 'In-app notifications'],
    stripePriceId: null,
  },
  {
    id: Plan.PRO,
    name: 'Pro',
    priceMonthlyUsd: 9,
    profileLimit: 100,
    features: [
      '100 monitored profiles',
      'Email + push notifications',
      'Faster check intervals',
      'Priority support',
    ],
    stripePriceId: null,
  },
  {
    id: Plan.BUSINESS,
    name: 'Business',
    priceMonthlyUsd: 29,
    profileLimit: null,
    features: [
      'Unlimited monitored profiles',
      'All notification channels',
      'Team access (coming soon)',
      'Dedicated support',
    ],
    stripePriceId: null,
  },
];

export const getPlan = (id: Plan): PlanDefinition =>
  PLANS.find((p) => p.id === id) ?? PLANS[0];
