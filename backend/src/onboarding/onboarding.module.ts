import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { FirebaseModule } from '../firebase/firebase.module.js';
import { SettlementsModule } from '../settlements/settlements.module.js';
import { KycModule } from '../kyc/kyc.module.js';
import { OnboardingController } from './onboarding.controller.js';
import { OnboardingService } from './onboarding.service.js';
@Module({ imports: [AuthModule, FirebaseModule, SettlementsModule, KycModule], controllers: [OnboardingController], providers: [OnboardingService] })
export class OnboardingModule {}
