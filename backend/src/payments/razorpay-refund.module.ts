import { Module } from '@nestjs/common';

import { FirebaseModule } from '../firebase/firebase.module.js';
import { RazorpayRefundService } from './razorpay-refund.service.js';

@Module({
  imports: [FirebaseModule],

  providers: [
    RazorpayRefundService,
  ],

  exports: [
    RazorpayRefundService,
  ],
})
export class RazorpayRefundModule {}