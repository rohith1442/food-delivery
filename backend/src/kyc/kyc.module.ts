import { Module } from '@nestjs/common';
import { KycStorageService } from './kyc-storage.service.js';

@Module({ providers: [KycStorageService], exports: [KycStorageService] })
export class KycModule {}
