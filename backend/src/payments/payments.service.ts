import {
  BadRequestException,
  Injectable,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Razorpay from 'razorpay';

import { OrdersService } from '../orders/orders.service.js';

@Injectable()
export class PaymentsService {
  private readonly razorpay: Razorpay;

  constructor(
    private readonly configService: ConfigService,
    private readonly ordersService: OrdersService,
  ) {
    const keyId =
      this.configService.get<string>('RAZORPAY_KEY_ID');

    const keySecret =
      this.configService.get<string>('RAZORPAY_KEY_SECRET');

    if (!keyId || !keySecret) {
      throw new Error(
        'Razorpay configuration is missing',
      );
    }

    this.razorpay = new Razorpay({
      key_id: keyId,
      key_secret: keySecret,
    });
  }

  async createRazorpayOrder(
    uid: string,
    body: any,
  ) {
    void uid;
    void body;

    throw new BadRequestException(
      'Razorpay order creation is not implemented yet',
    );
  }

  async verifyRazorpayPayment(
    uid: string,
    body: any,
  ) {
    void uid;
    void body;

    throw new BadRequestException(
      'Razorpay payment verification is not implemented yet',
    );
  }
}