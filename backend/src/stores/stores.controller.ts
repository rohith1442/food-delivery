import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard.js';
import { StoresService } from './stores.service.js';

@Controller()
@UseGuards(AuthGuard)
export class StoresController {
  constructor(
    private readonly storesService: StoresService,
  ) {}

  // ------------------------------
  // CUSTOMER
  // ------------------------------

  @Get('stores')
  async getStores(
    @Query('moduleId') moduleId?: string,
    @Query('zoneId') zoneId?: string,
  ) {
    return this.storesService.getStores(
      moduleId,
      zoneId,
    );
  }

  @Get('stores/:storeId')
  async getStore(
    @Param('storeId') storeId: string,
  ) {
    return this.storesService.getStore(
      storeId,
    );
  }

  // ------------------------------
  // MERCHANT
  // ------------------------------

  @Post('merchant/store')
  async createStore(
    @Req() request: any,
    @Body() body: any,
  ) {
    return this.storesService.createStore(
      request.user.uid,
      body,
    );
  }

  @Get('merchant/store')
  async getMerchantStore(
    @Req() request: any,
  ) {
    return this.storesService.getMerchantStore(
      request.user.uid,
    );
  }

  @Patch('merchant/store/:storeId/status')
  async updateStoreStatus(
    @Req() request: any,
    @Param('storeId') storeId: string,
    @Body('isOpen') isOpen: boolean,
  ) {
    return this.storesService.updateStoreStatus(
      request.user.uid,
      storeId,
      isOpen,
    );
  }
}