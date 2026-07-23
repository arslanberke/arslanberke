import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsBoolean } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AdminService } from './admin.service';

class SetDisabledDto {
  @ApiProperty()
  @IsBoolean()
  disabled: boolean;
}

@ApiTags('admin')
@ApiBearerAuth()
@Roles('ADMIN')
@UseGuards(RolesGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('users')
  @ApiOperation({ summary: 'List users' })
  users(@Query('search') search?: string) {
    return this.admin.listUsers(search);
  }

  @Get('profiles')
  @ApiOperation({ summary: 'List all monitored profiles' })
  profiles() {
    return this.admin.listProfiles();
  }

  @Patch('users/:id/disabled')
  @ApiOperation({ summary: 'Disable or enable a user account' })
  setDisabled(
    @CurrentUser() admin: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetDisabledDto,
  ) {
    return this.admin.setUserDisabled(id, dto.disabled, admin.id);
  }

  @Get('stats')
  @ApiOperation({ summary: 'Platform-wide statistics' })
  stats() {
    return this.admin.stats();
  }

  @Get('logs')
  @ApiOperation({ summary: 'Audit logs' })
  logs() {
    return this.admin.logs();
  }
}
