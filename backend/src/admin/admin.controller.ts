import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';

import { FileInterceptor } from '@nestjs/platform-express';

import { AuthGuard } from '../auth/auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { AdminService } from './admin.service.js';

@Controller('admin')
@UseGuards(AuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('users')
  async getUsers(
    @Query('status')
    status?: string,
  ) {
    return this.adminService.getUsers(status ?? 'PENDING');
  }

  @Patch('users/:uid/approve')
  async approveUser(
    @Param('uid')
    uid: string,
  ) {
    return this.adminService.approveUser(uid);
  }

  @Patch('users/:uid/reject')
  async rejectUser(
    @Param('uid')
    uid: string,
  ) {
    return this.adminService.rejectUser(uid);
  }

  @Get('orders')
  async getOrders(
    @Query('status')
    status?: string,
  ) {
    return this.adminService.getOrders(status);
  }
  @Get('stores')
  async getStores() {
    return this.adminService.getStores();
  }

  @Patch('stores/:storeId/status')
  async updateStoreStatus(
    @Param('storeId') storeId: string,
    @Body('isActive') isActive: boolean,
  ) {
    return this.adminService.updateStoreStatus(storeId, isActive);
  }

  @Get('users/all')
  async getAllUsers(
    @Query('role') role?: string,
    @Query('status') status?: string,
  ) {
    return this.adminService.getAllUsers(role, status);
  }

  @Patch('users/:uid/status')
  async updateUserStatus(
    @Param('uid') uid: string,
    @Body('isActive') isActive: boolean,
  ) {
    return this.adminService.updateUserStatus(uid, isActive);
  }

  @Patch('users/:uid/delivery-zone')
  async assignDeliveryZone(
    @Param('uid') uid: string,
    @Body('zoneId') zoneId: string,
  ) {
    return this.adminService.assignDeliveryZone(uid, zoneId);
  }

  @Get('orders/:orderId')
  async getOrder(@Param('orderId') orderId: string) {
    return this.adminService.getOrder(orderId);
  }
  @Get('zones')
  async getZones() {
    return this.adminService.getZones();
  }

 @Post('zones')
async createZone(
  @Body()
  body: {
    name: string;
    city?: string;
    state?: string;
    centerLatitude: number;
    centerLongitude: number;
    radiusKm: number;
  },
) {
  return this.adminService.createZone(body);
}

@Patch('zones/:zoneId')
async updateZone(
  @Param('zoneId') zoneId: string,
  @Body()
  body: {
    name?: string;
    city?: string;
    state?: string;
    centerLatitude?: number;
    centerLongitude?: number;
    radiusKm?: number;
  },
) {
  return this.adminService.updateZone(
    zoneId,
    body,
  );
}

  @Patch('zones/:zoneId/status')
  async updateZoneStatus(
    @Param('zoneId') zoneId: string,
    @Body('isActive') isActive: boolean,
  ) {
    return this.adminService.updateZoneStatus(zoneId, isActive);
  }
  @Get('modules')
  async getModules() {
    return this.adminService.getModules();
  }

  @Patch('modules/:moduleId/status')
  async updateModuleStatus(
    @Param('moduleId') moduleId: string,
    @Body('isActive') isActive: boolean,
  ) {
    return this.adminService.updateModuleStatus(moduleId, isActive);
  }

  @Patch('modules/:moduleId/order')
  async updateModuleOrder(
    @Param('moduleId') moduleId: string,
    @Body('sortOrder') sortOrder: number,
  ) {
    return this.adminService.updateModuleOrder(moduleId, sortOrder);
  }

  @Post('modules/:moduleId/image')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        fileSize: 5 * 1024 * 1024,
      },
    }),
  )
  async uploadModuleImage(
    @Param('moduleId') moduleId: string,
    @UploadedFile()
    file: Express.Multer.File,
  ) {
    return this.adminService.uploadModuleImage(moduleId, file);
  }

  @Get('dashboard')
  async getDashboard() {
    return this.adminService.getDashboard();
  }
  @Get('settlements')
  async getSettlements() {
    return this.adminService.getSettlements();
  }
  @Get('settings')
async getSettings() {
  return this.adminService.getSettings();
}

@Patch('settings')
async updateSettings(
  @Body()
  body: {
    deliveryFee?: number;
    minimumOrder?: number;
    maintenanceMode?: boolean;

    customerMinVersion?: string;
    customerForceUpdate?: boolean;

    merchantMinVersion?: string;
    merchantForceUpdate?: boolean;

    deliveryMinVersion?: string;
    deliveryForceUpdate?: boolean;

    appName?: string;
    shortName?: string;
    tagline?: string;
    logoUrl?: string;

    primaryColor?: string;
    secondaryColor?: string;
    accentColor?: string;

    currencySymbol?: string;
    supportPhone?: string;
    deliveryPromiseText?: string;

    home?: {
      enabledModules?: string[];
      sections?: Array<{
        id:
          | 'modules'
          | 'promo'
          | 'categories'
          | 'nearby';
        enabled: boolean;
        sortOrder: number;
      }>;
      promoBanner?: {
        enabled?: boolean;
        title?: string;
        subtitle?: string;
        imageUrl?: string;
        actionType?:
          | 'NONE'
          | 'MODULE'
          | 'CATEGORY';
        actionValue?: string;
      };
    };
    content?: Record<string, unknown>;
  },
) {
  return this.adminService.updateSettings(body);
}
}
