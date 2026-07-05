import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, Matches, MaxLength } from 'class-validator';

export class AddProfileDto {
  @ApiProperty({ example: 'natgeo', description: 'Instagram username to monitor' })
  @IsString()
  @MaxLength(30)
  @Matches(/^[a-zA-Z0-9._]+$/, {
    message: 'Username may only contain letters, numbers, dots and underscores',
  })
  username: string;
}

export class ListProfilesQueryDto {
  @ApiPropertyOptional({ description: 'Filter by username substring' })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  search?: string;
}
