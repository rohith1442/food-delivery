import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AuthModule } from './auth/auth.module.js';
import { FirebaseModule } from './firebase/firebase.module.js';
import { OrdersModule } from './orders/orders.module.js';
import { StoresModule } from './stores/stores.module.js';
import { CategoriesModule } from './categories/categories.module.js';
import { ProductsModule } from './products/products.module.js';
import { AdminModule } from './admin/admin.module.js';
import { SettingsModule } from './settings/settings.module.js';
import { ZonesModule } from './zones/zones.module.js';
import { AddressesModule } from './addresses/addresses.module.js';
import { UploadsModule } from './uploads/uploads.module.js';
import { PaymentsModule } from './payments/payments.module.js';
import { NotificationsModule } from './notifications/notifications.module.js';
import { ModulesModule } from './modules/modules.module.js';
import { SearchModule } from './search/search.module.js';
import { ReviewsModule } from './reviews/reviews.module.js';
import { SettlementsModule } from './settlements/settlements.module.js';
import { OnboardingModule } from './onboarding/onboarding.module.js';
import { KycModule } from './kyc/kyc.module.js';
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    FirebaseModule,
    AuthModule,
    OrdersModule,
    StoresModule,
    CategoriesModule,
    ProductsModule,
    AdminModule,
    SettingsModule,
    ZonesModule,
    AddressesModule,
    UploadsModule,
    PaymentsModule,
    NotificationsModule,
    ModulesModule,
    SearchModule,
    ReviewsModule,
    SettlementsModule,
    OnboardingModule,
    KycModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
