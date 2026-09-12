import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { AddressesService } from './addresses.service.js';

@Controller('addresses')
@UseGuards(AuthGuard, RolesGuard)
@Roles('CUSTOMER')
export class AddressesController {
  constructor(
    private readonly addressesService: AddressesService,
  ) {}

  @Get()
  async getAddresses(
    @Req() request: any,
  ) {
    return this.addressesService.getAddresses(
      request.user.uid,
    );
  }

  @Post()
  async createAddress(
    @Req() request: any,
    @Body() body: any,
  ) {
    return this.addressesService.createAddress(
      request.user.uid,
      body,
    );
  }

  @Patch(':addressId')
  async updateAddress(
    @Req() request: any,
    @Param('addressId') addressId: string,
    @Body() body: any,
  ) {
    return this.addressesService.updateAddress(
      request.user.uid,
      addressId,
      body,
    );
  }

  @Delete(':addressId')
  async deleteAddress(
    @Req() request: any,
    @Param('addressId') addressId: string,
  ) {
    return this.addressesService.deleteAddress(
      request.user.uid,
      addressId,
    );
  }

  @Patch(':addressId/default')
  async setDefaultAddress(
    @Req() request: any,
    @Param('addressId') addressId: string,
  ) {
    return this.addressesService.setDefaultAddress(
      request.user.uid,
      addressId,
    );
  }
}
