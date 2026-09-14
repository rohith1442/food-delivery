import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class RazorpayPayoutService {
  constructor(private readonly config: ConfigService) {}
  private get authHeader() { const id = this.config.get<string>('RAZORPAY_KEY_ID') ?? ''; const secret = this.config.get<string>('RAZORPAY_KEY_SECRET') ?? ''; return `Basic ${Buffer.from(`${id}:${secret}`).toString('base64')}`; }
  private async request(path: string, body: Record<string, unknown>, headers: Record<string, string> = {}) { if (!this.config.get<string>('RAZORPAY_X_PAYOUTS_ENABLED') || this.config.get<string>('RAZORPAY_X_PAYOUTS_ENABLED') !== 'true') throw new BadRequestException('RazorpayX payouts are disabled'); const response = await fetch(`https://api.razorpay.com${path}`, { method: 'POST', headers: { Authorization: this.authHeader, 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body) }); const data = await response.json() as any; if (!response.ok) throw new BadRequestException(data?.error?.description ?? 'RazorpayX request failed'); return data; }
  createContact(input: { name: string; email?: string; phone: string; referenceId: string }) { return this.request('/v1/contacts', { name: input.name, email: input.email, contact: input.phone, type: 'vendor', reference_id: input.referenceId }); }
  createBankFundAccount(input: { contactId: string; accountHolderName: string; ifsc: string; accountNumber: string }) { return this.request('/v1/fund_accounts', { contact_id: input.contactId, account_type: 'bank_account', bank_account: { name: input.accountHolderName, ifsc: input.ifsc, account_number: input.accountNumber } }); }
  createPayout(input: { fundAccountId: string; amountInPaise: number; payoutBatchId: string }) { return this.request('/v1/payouts', { account_number: this.config.get<string>('RAZORPAY_X_ACCOUNT_NUMBER'), fund_account_id: input.fundAccountId, amount: input.amountInPaise, currency: 'INR', mode: 'IMPS', purpose: 'payout', queue_if_low_balance: true, reference_id: input.payoutBatchId }, { 'X-Payout-Idempotency': input.payoutBatchId }); }
}
