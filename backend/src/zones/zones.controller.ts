import {
  BadRequestException,
  Controller,
  Get,
  Query,
} from '@nestjs/common';

import { ZonesService } from './zones.service.js';

@Controller('zones')
export class ZonesController {
  constructor(
    private readonly zonesService: ZonesService,
  ) {}

  @Get('resolve')
  async resolveZone(
    @Query('latitude') latitudeValue?: string,
    @Query('longitude') longitudeValue?: string,
  ) {
    if (
      latitudeValue === undefined ||
      longitudeValue === undefined
    ) {
      throw new BadRequestException(
        'latitude and longitude are required',
      );
    }

    const latitude = Number(latitudeValue);
    const longitude = Number(longitudeValue);

    if (
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude)
    ) {
      throw new BadRequestException(
        'latitude and longitude must be valid numbers',
      );
    }

    return this.zonesService.resolveZone(
      latitude,
      longitude,
    );
  }
}
