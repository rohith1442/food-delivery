import {
  BadRequestException,
  Controller,
  Headers,
  Post,
  Req,
} from '@nestjs/common';

import type { RawBodyRequest } from '@nestjs/common';
import type { Request } from 'express';

import { PaymentsService } from './payments.service.js';

@Controller('payments/razorpay')
export class RazorpayWebhookController {
  constructor(
    private readonly paymentsService: PaymentsService,
  ) {}

  @Post('webhook')
  async webhook(
    @Req() request: RawBodyRequest<Request>,
    @Headers('x-razorpay-signature')
    signature: string | undefined,
    @Headers('x-razorpay-event-id')
    eventId: string | undefined,
  ) {
    if (!request.rawBody) {
      throw new BadRequestException(
        'Webhook raw body is missing',
      );
    }

    if (!signature) {
      throw new BadRequestException(
        'Razorpay signature is missing',
      );
    }

    if (!eventId) {
      throw new BadRequestException(
        'Razorpay event ID is missing',
      );
    }

    return this.paymentsService.handleRazorpayWebhook(
      request.rawBody,
      signature,
      eventId,
    );
  }
}