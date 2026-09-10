import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { FirebaseModule } from '../firebase/firebase.module.js';
import { CategoriesController } from './categories.controller.js';
import { CategoriesService } from './categories.service.js';

@Module({
  imports: [
    FirebaseModule,
    AuthModule,
  ],
  controllers: [
    CategoriesController,
  ],
  providers: [
    CategoriesService,
  ],
  exports: [
    CategoriesService,
  ],
})
export class CategoriesModule {}