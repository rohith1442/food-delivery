import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { FirebaseModule } from '../firebase/firebase.module.js';
import { StoresController } from './stores.controller.js';
import { StoresService } from './stores.service.js';

@Module({
  imports: [
    FirebaseModule,
    AuthModule,
  ],
  controllers: [
    StoresController,
  ],
  providers: [
    StoresService,
  ],
  exports: [
    StoresService,
  ],
})
export class StoresModule {}