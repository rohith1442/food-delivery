import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  Query,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard.js';
import { CategoriesService } from './categories.service.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';

@Controller()
export class CategoriesController {
  constructor(
    private readonly categoriesService:
      CategoriesService,
  ) {}

  // MERCHANT

 @Post('merchant/categories')
@UseGuards(AuthGuard, RolesGuard)
@Roles('MERCHANT')
async createCategory(
  @Req() request: any,
  @Body() body: any,
) {
  return this.categoriesService.createCategory(
    request.user.uid,
    body,
  );
}

@Get('merchant/categories')
@UseGuards(AuthGuard, RolesGuard)
@Roles('MERCHANT')
async getMerchantCategories(
  @Req() request: any,
) {
  return this.categoriesService.getMerchantCategories(
    request.user.uid,
  );
}

@Patch('merchant/categories/:categoryId')
@UseGuards(AuthGuard, RolesGuard)
@Roles('MERCHANT')
async updateCategory(
  @Req() request: any,
  @Param('categoryId') categoryId: string,
  @Body() body: any,
) {
  return this.categoriesService.updateCategory(
    request.user.uid,
    categoryId,
    body,
  );
}

@Patch('merchant/categories/:categoryId/image')
@UseGuards(AuthGuard, RolesGuard)
@Roles('MERCHANT')
async updateCategoryImage(
  @Req() request: any,
  @Param('categoryId') categoryId: string,
  @Body() body: { imageUrl: string },
) {
  return this.categoriesService.updateCategoryImage(
    request.user.uid,
    categoryId,
    body.imageUrl,
  );
}

  // CUSTOMER

  @Get('categories')
  @UseGuards(AuthGuard)
  async getCategories(
    @Query('moduleId') moduleId?: string,
    @Query('zoneId') zoneId?: string,
  ) {
    return this.categoriesService.getCategories(
      moduleId,
      zoneId,
    );
  }

@Get('stores/:storeId/categories')
@UseGuards(AuthGuard)
async getStoreCategories(
  @Param('storeId') storeId: string,
) {
  return this.categoriesService.getStoreCategories(
    storeId,
  );
}
}
