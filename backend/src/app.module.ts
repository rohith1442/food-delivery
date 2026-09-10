import { Module } from '@nestjs/common';

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

@Module({
  imports: [
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
    UploadsModule
    
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}