import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { AddProfileDto, ListProfilesQueryDto } from './dto/profiles.dto';
import { ProfilesService } from './profiles.service';

@ApiTags('profiles')
@ApiBearerAuth()
@Controller('profiles')
export class ProfilesController {
  constructor(private readonly profiles: ProfilesService) {}

  @Get()
  @ApiOperation({ summary: 'List monitored profiles' })
  list(@CurrentUser() user: AuthUser, @Query() query: ListProfilesQueryDto) {
    return this.profiles.list(user.id, query.search);
  }

  @Post()
  @ApiOperation({ summary: 'Add a username to monitor' })
  add(@CurrentUser() user: AuthUser, @Body() dto: AddProfileDto) {
    return this.profiles.add(user.id, dto.username);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a monitored profile' })
  get(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.profiles.getOwned(user.id, id);
  }

  @Delete(':id')
  @HttpCode(204)
  @ApiOperation({ summary: 'Stop monitoring and remove a profile' })
  remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.profiles.remove(user.id, id);
  }

  @Patch(':id/pause')
  @ApiOperation({ summary: 'Pause monitoring' })
  pause(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.profiles.pause(user.id, id);
  }

  @Patch(':id/resume')
  @ApiOperation({ summary: 'Resume monitoring' })
  resume(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.profiles.resume(user.id, id);
  }

  @Get(':id/history')
  @ApiOperation({ summary: 'Status change history for a profile' })
  history(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.profiles.history(user.id, id);
  }
}
