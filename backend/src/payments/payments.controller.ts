import {
  Body,
  Controller,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { PaymentsService } from './payments.service.js';

@Controller('payments')
@UseGuards(AuthGuard, RolesGuard)
@Roles('CUSTOMER')
export class PaymentsController {
  constructor(
    private readonly paymentsService: PaymentsService,
  ) {}

  @Post('razorpay/order')
  async createRazorpayOrder(
    @Req() request: any,
    @Body() body: any,
  ) {
      console.log('=== RAZORPAY ORDER REQUEST RECEIVED ===');

  console.log('user:', request.user);

  console.log('body:', body);
    console.log('createRazorpayOrder called with body:', body);
    return this.paymentsService.createRazorpayOrder(
      request.user.uid,
      body,
    );
  }

  @Post('razorpay/verify')
  async verifyRazorpayPayment(
    @Req() request: any,
    @Body() body: any,
  ) {
    return this.paymentsService.verifyRazorpayPayment(
      request.user.uid,
      body,
    );
  }
}