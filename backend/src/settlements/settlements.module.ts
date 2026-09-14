import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { FirebaseModule } from '../firebase/firebase.module.js';
import { DeliverySettlementsController, MerchantSettlementsController, SettlementsController } from './settlements.controller.js';
import { SettlementsService } from './settlements.service.js';
import { RazorpayRouteService } from './razorpay-route.service.js';
import { RazorpayPayoutService } from './razorpay-payout.service.js';
@Module({ imports: [FirebaseModule, AuthModule], controllers: [SettlementsController, MerchantSettlementsController, DeliverySettlementsController], providers: [SettlementsService, RazorpayRouteService, RazorpayPayoutService], exports: [SettlementsService, RazorpayRouteService, RazorpayPayoutService] })
export class SettlementsModule {}
