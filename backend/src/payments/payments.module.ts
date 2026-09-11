import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { FirebaseModule } from '../firebase/firebase.module.js';
import { OrdersModule } from '../orders/orders.module.js';
import { PaymentsController } from './payments.controller.js';
import { PaymentsService } from './payments.service.js';

@Module({
  imports: [
    AuthModule,
    FirebaseModule,
    OrdersModule,
  ],
  controllers: [PaymentsController],
  providers: [PaymentsService],
})
export class PaymentsModule {}