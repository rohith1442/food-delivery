import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class RazorpayRouteService {
  private readonly keyId: string;
  private readonly keySecret: string;
  constructor(private readonly config: ConfigService) {
    this.keyId = this.config.get<string>('RAZORPAY_KEY_ID') ?? '';
    this.keySecret = this.config.get<string>('RAZORPAY_KEY_SECRET') ?? '';
  }

  private get enabled(): boolean {
    return this.config.get<string>('RAZORPAY_ROUTE_ENABLED') === 'true';
  }

  private ensureConfigured() {
    if (!this.enabled || !this.keyId || !this.keySecret) {
      throw new BadRequestException(
        'Razorpay Route is disabled or not configured',
      );
    }
  }

  private get authHeader() { return `Basic ${Buffer.from(`${this.keyId}:${this.keySecret}`).toString('base64')}`; }
  async transferPayment(input: { razorpayPaymentId: string; linkedAccountId: string; amountInPaise: number; orderId: string }) {
    this.ensureConfigured();
    const response = await fetch(`https://api.razorpay.com/v1/payments/${input.razorpayPaymentId}/transfers`, { method: 'POST', headers: { Authorization: this.authHeader, 'Content-Type': 'application/json' }, body: JSON.stringify({ transfers: [{ account: input.linkedAccountId, amount: input.amountInPaise, currency: 'INR', notes: { orderId: input.orderId } }] }) });
    const data = await response.json() as any;
    if (!response.ok) throw new BadRequestException(data?.error?.description ?? 'Merchant transfer failed');
    return data;
  }
  async createLinkedAccount(input: { uid: string; email: string; phone: string; legalBusinessName: string; customerFacingBusinessName: string; businessType: string }) {
    this.ensureConfigured();
    const response = await fetch('https://api.razorpay.com/v2/accounts', { method: 'POST', headers: { Authorization: this.authHeader, 'Content-Type': 'application/json' }, body: JSON.stringify({ email: input.email, phone: input.phone, legal_business_name: input.legalBusinessName, customer_facing_business_name: input.customerFacingBusinessName, business_type: input.businessType, reference_id: input.uid }) });
    const data = await response.json() as any;
    if (!response.ok) throw new BadRequestException(data?.error?.description ?? 'Unable to create Razorpay linked account');
    return data;
  }
}
