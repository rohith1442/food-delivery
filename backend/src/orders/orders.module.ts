import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { FirebaseModule } from '../firebase/firebase.module.js';
import { DeliveryPartnerController } from './delivery_partner.controller.js';
import { DeliveryOrdersController } from './delivery_orders.controller.js';
import { MerchantOrdersController } from './merchant_orders.controller.js';
import { OrdersController } from './orders.controller.js';
import { OrdersService } from './orders.service.js';
import { RazorpayRefundModule } from '../payments/razorpay-refund.module.js';

@Module({
  imports: [
    FirebaseModule,
    AuthModule,
    RazorpayRefundModule
  ],
  controllers: [
    OrdersController,
    MerchantOrdersController,
    DeliveryOrdersController,
    DeliveryPartnerController,
  ],
  providers: [OrdersService],
  exports: [OrdersService],
})
export class OrdersModule {}
