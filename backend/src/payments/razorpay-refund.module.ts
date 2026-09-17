import { Module } from '@nestjs/common';

import { FirebaseModule } from '../firebase/firebase.module.js';
import { RazorpayRefundService } from './razorpay-refund.service.js';
import { SettlementsModule } from '../settlements/settlements.module.js';

@Module({
  imports: [FirebaseModule, SettlementsModule],

  providers: [
    RazorpayRefundService,
  ],

  exports: [
    RazorpayRefundService,
  ],
})
export class RazorpayRefundModule {}
