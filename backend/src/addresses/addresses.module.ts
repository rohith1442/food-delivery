import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { FirebaseModule } from '../firebase/firebase.module.js';
import { ZonesModule } from '../zones/zones.module.js';
import { AddressesController } from './addresses.controller.js';
import { AddressesService } from './addresses.service.js';

@Module({
  imports: [
    FirebaseModule,
    AuthModule,
    ZonesModule,
  ],
  controllers: [
    AddressesController,
  ],
  providers: [
    AddressesService,
  ],
  exports: [
    AddressesService,
  ],
})
export class AddressesModule {}
