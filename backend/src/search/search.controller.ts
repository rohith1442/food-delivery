import {
  Controller,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { SearchService } from './search.service.js';

@Controller('search')
@UseGuards(AuthGuard, RolesGuard)
@Roles('CUSTOMER')
export class SearchController {
  constructor(
    private readonly searchService: SearchService,
  ) {}

  @Get()
  async search(
    @Query('zoneId') zoneId?: string,
    @Query('q') query?: string,
  ) {
    return this.searchService.search(zoneId, query);
  }
}
