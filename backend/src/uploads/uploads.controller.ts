import {
  Controller,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';

import { FileInterceptor } from '@nestjs/platform-express';

import { AuthGuard } from '../auth/auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';

import { UploadsService } from './uploads.service.js';

@Controller()
export class UploadsController {
  constructor(
    private readonly uploadsService:
      UploadsService,
  ) {}

  @Post('merchant/products/images')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('MERCHANT')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        fileSize: 5 * 1024 * 1024,
      },
    }),
  )
  async uploadProductImage(
    @Req() request: any,
    @UploadedFile()
    file: Express.Multer.File,
  ) {
    return this.uploadsService
      .uploadProductImage(
        request.user.uid,
        file,
      );
  }

  @Post('merchant/store/image')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('MERCHANT')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        fileSize: 5 * 1024 * 1024,
      },
    }),
  )
  async uploadStoreImage(
    @Req() request: any,
    @UploadedFile()
    file: Express.Multer.File,
  ) {
    return this.uploadsService.uploadStoreImage(
      request.user.uid,
      file,
    );
  }

  @Post('merchant/categories/images')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('MERCHANT')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        fileSize: 5 * 1024 * 1024,
      },
    }),
  )
  async uploadCategoryImage(
    @Req() request: any,
    @UploadedFile()
    file: Express.Multer.File,
  ) {
    return this.uploadsService.uploadCategoryImage(
      request.user.uid,
      file,
    );
  }
}
