#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include<ctype.h>

typedef uint8_t bool;
#define true 1
#define false 0


typedef struct
{
    uint8_t BootJumpInstruction[3];
    uint8_t OEMID[8];
    uint16_t BytesPerSector;
    uint8_t SectorPerCluster;
    uint16_t ReservedSectors;
    uint8_t FATCount;
    uint16_t DirEntries;
    uint16_t TotalSectors;
    uint8_t MediaDescriptor;
    uint16_t SectorsPerFAT;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectors;


    // extended boot record
    uint8_t DriveNumber;
    uint8_t _Reserved;
    uint8_t Signature;
    uint32_t VolumeID;
    uint8_t VolumeLabel[11];
    uint8_t SystemID[8];
    
} __attribute__((packed)) BootSector;

typedef struct{

    uint8_t Name[11];
    uint8_t Attribute;
    uint8_t _Reserved;
    uint8_t CreatedTimeTenths;
    uint16_t CreateTime;
    uint16_t CreateDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifyTime;
    uint16_t ModifyDate;
    uint16_t FirstClusterLow;
    uint32_t Size;
}__attribute__((packed)) DirectoryEntry;

BootSector bootSector;
uint8_t* fat = NULL;
DirectoryEntry* rootDir =NULL;
uint32_t rootDirEnd;




bool readBootSector(FILE* disk){
    return fread(&bootSector,sizeof(bootSector),1 ,disk);
}

bool readSectors(FILE* disk, uint32_t lba, uint32_t count, void* bufferOut){
    
    bool ok= true;
    ok = ok && (fseek(disk, lba * bootSector.BytesPerSector, SEEK_SET) == 0);
    ok = ok && (fread(bufferOut, bootSector.BytesPerSector, count, disk) == count);
    return ok;
}

bool readFat(FILE* disk){

    fat = (uint8_t*) malloc(bootSector.SectorsPerFAT * bootSector.BytesPerSector);
    return readSectors(disk, bootSector.ReservedSectors, bootSector.SectorsPerFAT, fat);

} 

bool readRootDir(FILE* disk){
    uint32_t lba = bootSector.ReservedSectors+ bootSector.SectorsPerFAT * bootSector.FATCount;
    uint32_t size = sizeof(DirectoryEntry) *bootSector.DirEntries;
    uint32_t sectors = (size / bootSector.BytesPerSector);
    if(size % bootSector.BytesPerSector > 0)
        sectors++;
    
    rootDirEnd = sectors + lba;
    rootDir = (DirectoryEntry*)malloc(sectors*bootSector.BytesPerSector);
    return readSectors(disk, lba, sectors, rootDir);

}


DirectoryEntry* FindFile(const char* name){
    for(uint32_t x = 0; x < bootSector.DirEntries; x++){
        if(memcmp(name, rootDir[x].Name, 11) == 0)
            return &rootDir[x];
    }
    return NULL;
}

bool readFile(DirectoryEntry* fileEntry, FILE* disk, uint8_t* outputBuffer){
    
    bool ok = true;
    uint16_t currentCluster = fileEntry -> FirstClusterLow;

    do{
        uint32_t lba = rootDirEnd + (currentCluster - 2) * bootSector.SectorPerCluster;
        ok = ok && readSectors(disk, lba, bootSector.SectorPerCluster, outputBuffer);
        outputBuffer += bootSector.SectorPerCluster * bootSector.BytesPerSector;

        uint32_t fatIndex = currentCluster * 3 / 2;
        if(currentCluster % 2 == 0)
            currentCluster = (*(uint16_t*)(fat + fatIndex)) & 0x0FFF;
        else
            currentCluster = (*(uint16_t*)(fat + fatIndex)) >> 4;
        

    }while(ok && currentCluster == 0x0FF8);

}

int main(int argc, char** argv){
    if(argc < 3){
        printf("Syntax %s <disk image> <file name>\n", argv[0]);
        return -1;
    }

    FILE* disk = fopen(argv[1], "rb");

    if(!disk){
        fprintf(stderr, "Cannot open disk image %s!", argv[1]);
        return-1;
    }

    if(!readBootSector(disk)){
        fprintf(stderr, "Could not reat boot sector! \n");
        return -2;
    }

    if(!readFat(disk)){
        fprintf(stderr, "Could not read FAT \n");
        free(fat);
        return -3;
    }

    if(!readRootDir(disk)){
        fprintf(stderr, "Could not read root directory \n");
        free(fat);
        free(rootDir);
        return -4;
    }
    DirectoryEntry* fileEntry = FindFile(argv[2]);
    if(!fileEntry){
        fprintf(stderr, "Could not find file %s \n", argv[2]);
        free(fat);
        free(rootDir);
        return -5;
    }

    uint8_t* buffer = (uint8_t*) malloc(fileEntry->Size + bootSector.BytesPerSector);
    if(!readFile(fileEntry, disk, buffer)){
        fprintf(stderr, "Could not read file %s \n", argv[2]);
        free(fat);
        free(rootDir);
        free(buffer);
        return -6;
    }
    for(size_t x = 0; x < fileEntry->Size; x++){
        if(isprint(buffer[x])) fputc(buffer[x], stdout);
        else printf("<%02x>", buffer[x]);
    }
    printf("\n");

    // print fat count
    uint32_t fatCount = 0;
    for(uint32_t x = 0; x < bootSector.SectorsPerFAT * bootSector.BytesPerSector; x++){
        if(fat[x] == 0) fatCount++;
    }

    printf("Free space: %d clusters\n", fatCount);

    free(fat);
    free(rootDir);

    return 0;

}