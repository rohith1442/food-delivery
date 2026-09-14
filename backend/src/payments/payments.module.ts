import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { FirebaseModule } from '../firebase/firebase.module.js';
import { OrdersModule } from '../orders/orders.module.js';

import { PaymentsController } from './payments.controller.js';
import { PaymentsService } from './payments.service.js';
import { RazorpayWebhookController } from './razorpay-webhook.controller.js';
import { RazorpayRefundModule } from './razorpay-refund.module.js';
import { SettlementsModule } from '../settlements/settlements.module.js';

@Module({
  imports: [
    AuthModule,
    FirebaseModule,
    RazorpayRefundModule,
    OrdersModule,
    SettlementsModule,
  ],
  controllers: [
    PaymentsController,
    RazorpayWebhookController,
  ],
  providers: [PaymentsService],
})
export class PaymentsModule {}
