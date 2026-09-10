import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { FirebaseModule } from '../firebase/firebase.module.js';
import { AdminController } from './admin.controller.js';
import { AdminService } from './admin.service.js';

@Module({
  imports: [
    AuthModule,
    FirebaseModule,
  ],
  controllers: [
    AdminController,
  ],
  providers: [
    AdminService,
  ],
})
export class AdminModule {}