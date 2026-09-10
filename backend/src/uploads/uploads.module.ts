import { Module } from '@nestjs/common';

import { UploadsController } from './uploads.controller.js';
import { UploadsService } from './uploads.service.js';
import { AuthModule } from '../auth/auth.module.js';

@Module({
    imports: [AuthModule],
  controllers: [UploadsController],
  providers: [UploadsService],
})
export class UploadsModule {}