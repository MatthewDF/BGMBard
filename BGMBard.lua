addon.name      = 'BGMBard'
addon.author    = 'Mazu'
addon.version   = '1.4'
addon.desc      = 'Sets day/night music in any zone'

require('common')
local ffi = require('ffi')
local imgui = require('imgui')
local settings = require('settings')

------------------------------------------------------------
-- Settings & Runtime State
------------------------------------------------------------
local bgm_bard_settings = T{
    overrides = T{},
	advanced_mode = false,
};

local music_settings = settings.load(bgm_bard_settings);


local state = {
    ui_open = { false },
    selected_target_idx = 1,
	text_buffers = {}
}

-- Packet FFI CDefinition
ffi.cdef [[
// PS2: GP_SERV_POS_HEAD
typedef struct
{
    uint32_t            UniqueNo;
    uint16_t            ActIndex;
    uint8_t             padding06;
    int8_t              dir;
    float               x;
    float               z;
    float               y;
    uint32_t            flags1;
    uint8_t             Speed;
    uint8_t             SpeedBase;
    uint8_t             HpMax;
    uint8_t             server_status;
    uint32_t            flags2;
    uint32_t            flags3;
    uint32_t            flags4;
    uint32_t            BtTargetID;
} GP_SERV_POS_HEAD;

// PS2: SAVE_LOGIN_STATE (Removed 'class' and ': uint32_t')
typedef enum
{
    SAVE_LOGIN_STATE_NONE           = 0,
    SAVE_LOGIN_STATE_MYROOM          = 1,
    SAVE_LOGIN_STATE_GAME            = 2,
    SAVE_LOGIN_STATE_POLEXIT         = 3,
    SAVE_LOGIN_STATE_JOBEXIT         = 4,
    SAVE_LOGIN_STATE_POLEXIT_MYROOM = 5,
    SAVE_LOGIN_STATE_END            = 6
} SAVE_LOGIN_STATE;

// PS2: GP_MYROOM_DANCER
typedef struct
{
    uint16_t            mon_no;
    uint16_t            face_no;
    uint8_t             mjob_no;
    uint8_t             hair_no;
    uint8_t             size;
    uint8_t             sjob_no;
    uint32_t            get_job_flag;
    int8_t              job_lev[16];
    uint16_t            bp_base[7];
    int16_t             bp_adj[7];
    int32_t             hpmax;
    int32_t             mpmax;
    uint8_t             sjobflg;
    uint8_t             unknown41[3];
} GP_MYROOM_DANCER_PKT;

// PS2: SAVE_CONF
typedef struct
{
    uint32_t            unknown00[3];
} SAVE_CONF_PKT;

// PS2: GP_SERV_LOGIN
typedef struct
{
    // Bitfields: Ensure these match the actual memory layout
    uint16_t                id_size; 
    uint16_t                sync;

    GP_SERV_POS_HEAD        PosHead;
    uint32_t                ZoneNo;
    uint32_t                ntTime;
    uint32_t                ntTimeSec;
    uint32_t                GameTime;
    uint16_t                EventNo;
    uint16_t                MapNumber;
    uint16_t                GrapIDTbl[9];
    uint16_t                MusicNum[5];
    uint16_t                SubMapNumber;
    uint16_t                EventNum;
    uint16_t                EventPara;
    uint16_t                EventMode;
    uint16_t                WeatherNumber;
    uint16_t                WeatherNumber2;
    uint32_t                WeatherTime;
    uint32_t                WeatherTime2;
    uint32_t                WeatherOffsetTime;
    uint32_t                ShipStart;
    uint16_t                ShipEnd;
    uint16_t                IsMonstrosity;
    uint32_t                LoginState; // Enums in structs are best handled as the base type
    char                    name[16];
    int32_t                 certificate[2];
    uint16_t                unknown9C;
    uint16_t                ZoneSubNo;
    uint32_t                PlayTime;
    uint32_t                DeadCounter;
    uint8_t                 MyroomSubMapNumber;
    uint8_t                 unknownA9;
    uint16_t                MyroomMapNumber;
    uint16_t                SendCount;
    uint8_t                 MyRoomExitBit;
    uint8_t                 MogZoneFlag;
    GP_MYROOM_DANCER_PKT    Dancer;
    SAVE_CONF_PKT           ConfData;
    uint32_t                Ex;
} GP_SERV_LOGIN;
]]

-- A list of music/bgws that can be used to rep music
-- Format: [ZoneID] = Zone Name, Zone Music (bgw file #)
local zoneData = T{
    [1]   = { name = 'Phanauet Channel', music = 229 },
    [3]   = { name = 'Manaclipper', music = 229 },
    [9]   = { name = 'PsoXja', music = 225 },
    [11]  = { name = 'Oldton Movalpolos', music = 221 },
    [12]  = { name = 'Newton Movalpolos', music = 221 },
    [15]  = { name = 'Abyssea-Konschtat', music = 51 },
    [16]  = { name = 'Promyvion-Holla', music = 222 },
    [18]  = { name = 'Promyvion-Dem', music = 222 },
    [20]  = { name = 'Promyvion-Mea', music = 222 },
    [22]  = { name = 'Promyvion-Vahzl', music = 222 },
    [24]  = { name = 'Lufaise Meadows', music = 230 },
    [25]  = { name = 'Misareaux Coast', music = 230 },
    [26]  = { name = 'Tavnazian Safehold', music = 245 },
    [32]  = { name = 'Sealions Den', music = 245 },
    [33]  = { name = 'AlTaieu', music = 233 },
    [35]  = { name = 'The Garden of RuHmet', music = 228 },
    [39]  = { name = 'Dynamis-Valkurm', music = 121 },
    [40]  = { name = 'Dynamis-Buburimu', music = 121 },
    [41]  = { name = 'Dynamis-Qufim', music = 121 },
    [42]  = { name = 'Dynamis-Tavnazia', music = 121 },
    [45]  = { name = 'Abyssea-Tahrongi', music = 51 },
    [46]  = { name = 'Open sea route to Al Zahbi', music = 147 },
    [47]  = { name = 'Open sea route to Mhaura', music = 147 },
    [48]  = { name = 'Al Zahbi', music = 178 },
    [50]  = { name = 'Aht Urhgan Whitegate', music = 178 },
    [51]  = { name = 'Wajaom Woodlands', music = 149 },
    [52]  = { name = 'Bhaflau Thickets', music = 149 },
    [53]  = { name = 'Nashmau', music = 175 },
    [54]  = { name = 'Arrapago Reef', music = 150 },
    [58]  = { name = 'Silver Sea route to Nashmau', music = 147 },
    [59]  = { name = 'Silver Sea route to Al Zahbi', music = 147 },
    [60]  = { name = 'The Ashu Talif', music = 172 },
    [68]  = { name = 'Aydeewa Subterrane', music = 174 },
    [70]  = { name = 'Chocobo Circuit', music = 176 },
    [73]  = { name = 'Zhayolm Remnants', music = 148 },
    [74]  = { name = 'Arrapago Remnants', music = 148 },
    [75]  = { name = 'Bhaflau Remnants', music = 148 },
    [76]  = { name = 'Silver Sea Remnants', music = 148 },
    [77]  = { name = 'Nyzul Isle', music = 148 },
    [79]  = { name = 'Caedarva Mire', music = 173 },
    [80]  = { name = 'Southern San dOria [S]', music = 254 },
    [81]  = { name = 'East Ronfaure [S]', music = 251 },
    [84]  = { name = 'Batallia Downs [S]', music = 252 },
    [85]  = { name = 'La Vaule [S]', music = 44 },
    [87]  = { name = 'Bastok Markets [S]', music = 180 },
    [88]  = { name = 'North Gustaberg [S]', music = 253 },
    [91]  = { name = 'Rolanberry Fields [S]', music = 252 },
    [92]  = { name = 'Beadeaux [S]', music = 44 },
    [94]  = { name = 'Windurst Waters [S]', music = 182 },
    [95]  = { name = 'West Sarutabaruta [S]', music = 141 },
    [98]  = { name = 'Sauromugue Champaign [S]', music = 252 },
    [99]  = { name = 'Castle Oztroja [S]', music = 44 },
    [100] = { name = 'West Ronfaure', music = 109 },
    [101] = { name = 'East Ronfaure', music = 109 },
	[102] = { name = 'La Theine Plateau', music = 608 }, -- HXI Custom
	[103] = { name = 'Valkurm Dunes', music = 606 }, -- HXI Custom
	[104] = { name = 'Jugner Forest', music = 621 }, -- HXI Custom
    [105] = { name = 'Batallia Downs', music = 114 },
    [106] = { name = 'North Gustaberg', music = 116 },
    [107] = { name = 'South Gustaberg', music = 116 },
    [108] = { name = 'Konschtat Highlands', music = 607 }, -- HXI Custom
    [110] = { name = 'Rolanberry Fields', music = 118 },
    [112] = { name = 'Xarcabard', music = 164 },
    [114] = { name = 'Eastern Altepa Desert', music = 171 },
    [115] = { name = 'West Sarutabaruta', music = 113 },
    [116] = { name = 'East Sarutabaruta', music = 113 },
    [117] = { name = 'Tahrongi Canyon', music =  612}, -- HXI Custom
    --[118] = { name = 'Buburimu Peninsula', music =  }, -- HXI Custom
    [120] = { name = 'Sauromugue Champaign', music = 158 },
    [121] = { name = 'The Sanctuary of ZiTah', music = 190 },
    [122] = { name = 'RoMaeve', music = 211 },
    [123] = { name = 'Yuhtunga Jungle', music = 134 },
    [124] = { name = 'Yhoator Jungle', music = 134 },
    [125] = { name = 'Western Altepa Desert', music = 171 },
    [130] = { name = 'RuAun Gardens', music = 210 },
    [132] = { name = 'Abyssea-La Theine', music = 51 },
    [134] = { name = 'Dynamis-Beaucedine', music = 121 },
    [135] = { name = 'Dynamis-Xarcabard', music = 119 },
    [137] = { name = 'Xarcabard [S]', music = 42 },
    [138] = { name = 'Castle Zvahl Baileys [S]', music = 43 },
    [155] = { name = 'Castle Zvahl Keep [S]', music = 43 },
    [161] = { name = 'Castle Zvahl Baileys', music = 155 },
    [162] = { name = 'Castle Zvahl Keep', music = 155 },
    [165] = { name = 'Throne Room', music = 155 },
    [177] = { name = 'VeLugannon Palace', music = 207 },
    [178] = { name = 'The Shrine of RuAvitau', music = 207 },
    [185] = { name = 'Dynamis-San dOria', music = 121 },
    [186] = { name = 'Dynamis-Bastok', music = 121 },
    [187] = { name = 'Dynamis-Windurst', music = 121 },
    [188] = { name = 'Dynamis-Jeuno', music = 121 },
    [215] = { name = 'Abyssea-Attohwa', music = 51 },
    [216] = { name = 'Abyssea-Misareaux', music = 51 },
    [217] = { name = 'Abyssea-Vunkerl', music = 51 },
    [218] = { name = 'Abyssea-Altepa', music = 51 },
    [220] = { name = 'Ship bound for Selbina', music = 106 },
    [221] = { name = 'Ship bound for Mhaura', music = 106 },
    [222] = { name = 'Provenance', music = 56 },
    [223] = { name = 'San dOria-Jeuno Airship', music = 128 },
    [224] = { name = 'Bastok-Jeuno Airship', music = 128 },
    [225] = { name = 'Windurst-Jeuno Airship', music = 128 },
    [226] = { name = 'Kazham-Jeuno Airship', music = 128 },
    [227] = { name = 'Ship bound for Selbina Pirates', music = 106 },
    [228] = { name = 'Ship bound for Mhaura Pirates', music = 106 },
    [230] = { name = 'Southern San dOria', music = 107 },
    [231] = { name = 'Northern San dOria', music = 107 },
    [232] = { name = 'Port San dOria', music = 107 },
    [233] = { name = 'Chateau dOraguille', music = 156 },
    [234] = { name = 'Bastok Mines', music = 152 },
    [235] = { name = 'Bastok Markets', music = 152 },
    [236] = { name = 'Port Bastok', music = 152 },
    [237] = { name = 'Metalworks', music = 154 },
    [238] = { name = 'Windurst Waters', music = 151 },
    [239] = { name = 'Windurst Walls', music = 151 },
    [240] = { name = 'Port Windurst', music = 151 },
    [241] = { name = 'Windurst Woods', music = 151 },
    [242] = { name = 'Heavens Tower', music = 162 },
    [243] = { name = 'RuLude Gardens', music = 117 },
    [244] = { name = 'Upper Jeuno', music = 110 },
    [245] = { name = 'Lower Jeuno', music = 110 },
    [246] = { name = 'Port Jeuno', music = 110 },
    [247] = { name = 'Rabao', music = 208 },
    [248] = { name = 'Selbina', music = 112 },
    [249] = { name = 'Mhaura', music = 105 },
    [250] = { name = 'Kazham', music = 135 },
    [251] = { name = 'Hall of the Gods', music = 213 },
    [252] = { name = 'Norg', music = 209 },
    [253] = { name = 'Abyssea-Uleguerand', music = 51 },
    [254] = { name = 'Abyssea-Grauberg', music = 51 },
    [255] = { name = 'Abyssea-Empyreal Paradox', music = 51 },
    [256] = { name = 'Western Adoulin', music = 59 },
    [257] = { name = 'Eastern Adoulin', music = 63 },
    [258] = { name = 'Rala Waterways', music = 61 },
    [259] = { name = 'Rala Waterways U', music = 61 },
    [260] = { name = 'Yahse Hunting Grounds', music = 60 },
    [261] = { name = 'Ceizak Battlegrounds', music = 60 },
    [262] = { name = 'Foret de Hennetiel', music = 60 },
    [263] = { name = 'Yorcia Weald', music = 61 },
    [264] = { name = 'Yorcia Weald U', music = 62 },
    [265] = { name = 'Morimar Basalt Fields', music = 60 },
    [266] = { name = 'Marjami Ravine', music = 60 },
    [267] = { name = 'Kamihr Drifts', music = 72 },
    [271] = { name = 'Cirdas Caverns U', music = 62 },
    [274] = { name = 'Outer RaKaznar', music = 73 },
    [275] = { name = 'Outer RaKaznar U', music = 62 },
    [276] = { name = 'RaKaznar Inner Court', music = 73 },
    [280] = { name = 'Mog Garden', music = 67 },
    [284] = { name = 'Celennia Memorial Library', music = 63 },
    [288] = { name = 'Escha ZiTah', music = 80 },
    [289] = { name = 'Escha RuAun', music = 80 },
    [291] = { name = 'Reisenjima', music = 79 },
    [294] = { name = 'Dynamis-San dOria [D]', music = 88 },
    [295] = { name = 'Dynamis-Bastok [D]', music = 88 },
    [296] = { name = 'Dynamis-Windurst [D]', music = 88 },
    [297] = { name = 'Dynamis-Jeuno [D]', music = 88 },
}

-- A full list of zones with their zone ID
local selectableZones = T{
    { id = 1, name = 'Phanauet Channel' },
    { id = 2, name = 'Carpenters Landing' },
    { id = 3, name = 'Manaclipper' },
    { id = 4, name = 'Bibiki Bay' },
    { id = 5, name = 'Uleguerand Range' },
    { id = 6, name = 'Bearclaw Pinnacle' },
    { id = 7, name = 'Attohwa Chasm' },
    { id = 8, name = 'Boneyard Gully' },
    { id = 9, name = 'PsoXja' },
    { id = 10, name = 'The Shrouded Maw' },
    { id = 11, name = 'Oldton Movalpolos' },
    { id = 12, name = 'Newton Movalpolos' },
    { id = 13, name = 'Mine Shaft 2716' },
    { id = 14, name = 'Hall of Transference' },
    { id = 15, name = 'Abyssea-Konschtat' },
    { id = 16, name = 'Promyvion-Holla' },
    { id = 17, name = 'Spire of Holla' },
    { id = 18, name = 'Promyvion-Dem' },
    { id = 19, name = 'Spire of Dem' },
    { id = 20, name = 'Promyvion-Mea' },
    { id = 21, name = 'Spire of Mea' },
    { id = 22, name = 'Promyvion-Vahzl' },
    { id = 23, name = 'Spire of Vahzl' },
    { id = 24, name = 'Lufaise Meadows' },
    { id = 25, name = 'Misareaux Coast' },
    { id = 26, name = 'Tavnazian Safehold' },
    { id = 27, name = 'Phomiuna Aqueducts' },
    { id = 28, name = 'Sacrarium' },
    { id = 29, name = 'Riverne-Site B01' },
    { id = 30, name = 'Riverne-Site A01' },
    { id = 31, name = 'Monarch Linn' },
    { id = 32, name = 'Sealions Den' },
    { id = 33, name = 'AlTaieu' },
    { id = 34, name = 'Grand Palace of HuXzoi' },
    { id = 35, name = 'The Garden of RuHmet' },
    { id = 36, name = 'Empyreal Paradox' },
    { id = 37, name = 'Temenos' },
    { id = 38, name = 'Apollyon' },
    { id = 39, name = 'Dynamis-Valkurm' },
    { id = 40, name = 'Dynamis-Buburimu' },
    { id = 41, name = 'Dynamis-Qufim' },
    { id = 42, name = 'Dynamis-Tavnazia' },
    { id = 43, name = 'Diorama Abdhaljs-Ghelsba' },
    { id = 44, name = 'Abdhaljs Isle-Purgonorgo' },
    { id = 45, name = 'Abyssea-Tahrongi' },
    { id = 46, name = 'Open sea route to Al Zahbi' },
    { id = 47, name = 'Open sea route to Mhaura' },
    { id = 48, name = 'Al Zahbi' },
    { id = 50, name = 'Aht Urhgan Whitegate' },
    { id = 51, name = 'Wajaom Woodlands' },
    { id = 52, name = 'Bhaflau Thickets' },
    { id = 53, name = 'Nashmau' },
    { id = 54, name = 'Arrapago Reef' },
    { id = 55, name = 'Ilrusi Atoll' },
    { id = 56, name = 'Periqia' },
    { id = 57, name = 'Talacca Cove' },
    { id = 58, name = 'Silver Sea route to Nashmau' },
    { id = 59, name = 'Silver Sea route to Al Zahbi' },
    { id = 60, name = 'The Ashu Talif' },
    { id = 61, name = 'Mount Zhayolm' },
    { id = 62, name = 'Halvung' },
    { id = 63, name = 'Lebros Cavern' },
    { id = 64, name = 'Navukgo Execution Chamber' },
    { id = 65, name = 'Mamook' },
    { id = 66, name = 'Mamool Ja Training Grounds' },
    { id = 67, name = 'Jade Sepulcher' },
    { id = 68, name = 'Aydeewa Subterrane' },
    { id = 69, name = 'Leujaoam Sanctum' },
    { id = 70, name = 'Chocobo Circuit' },
    { id = 71, name = 'The Colosseum' },
    { id = 72, name = 'Alzadaal Undersea Ruins' },
    { id = 73, name = 'Zhayolm Remnants' },
    { id = 74, name = 'Arrapago Remnants' },
    { id = 75, name = 'Bhaflau Remnants' },
    { id = 76, name = 'Silver Sea Remnants' },
    { id = 77, name = 'Nyzul Isle' },
    { id = 78, name = 'Hazhalm Testing Grounds' },
    { id = 79, name = 'Caedarva Mire' },
    { id = 80, name = 'Southern San dOria [S]' },
    { id = 81, name = 'East Ronfaure [S]' },
    { id = 82, name = 'Jugner Forest [S]' },
    { id = 83, name = 'Vunkerl Inlet [S]' },
    { id = 84, name = 'Batallia Downs [S]' },
    { id = 85, name = 'La Vaule [S]' },
    { id = 86, name = 'Everbloom Hollow' },
    { id = 87, name = 'Bastok Markets [S]' },
    { id = 88, name = 'North Gustaberg [S]' },
    { id = 89, name = 'Grauberg [S]' },
    { id = 90, name = 'Pashhow Marshlands [S]' },
    { id = 91, name = 'Rolanberry Fields [S]' },
    { id = 92, name = 'Beadeaux [S]' },
    { id = 93, name = 'Ruhotz Silvermines' },
    { id = 94, name = 'Windurst Waters [S]' },
    { id = 95, name = 'West Sarutabaruta [S]' },
    { id = 96, name = 'Fort Karugo-Narugo [S]' },
    { id = 97, name = 'Meriphataud Mountains [S]' },
    { id = 98, name = 'Sauromugue Champaign [S]' },
    { id = 99, name = 'Castle Oztroja [S]' },
    { id = 100, name = 'West Ronfaure' },
    { id = 101, name = 'East Ronfaure' },
    { id = 102, name = 'La Theine Plateau' },
    { id = 103, name = 'Valkurm Dunes' },
    { id = 104, name = 'Jugner Forest' },
    { id = 105, name = 'Batallia Downs' },
    { id = 106, name = 'North Gustaberg' },
    { id = 107, name = 'South Gustaberg' },
    { id = 108, name = 'Konschtat Highlands' },
    { id = 109, name = 'Pashhow Marshlands' },
    { id = 110, name = 'Rolanberry Fields' },
    { id = 111, name = 'Beaucedine Glacier' },
    { id = 112, name = 'Xarcabard' },
    { id = 113, name = 'Cape Teriggan' },
    { id = 114, name = 'Eastern Altepa Desert' },
    { id = 115, name = 'West Sarutabaruta' },
    { id = 116, name = 'East Sarutabaruta' },
    { id = 117, name = 'Tahrongi Canyon' },
    { id = 118, name = 'Buburimu Peninsula' },
    { id = 119, name = 'Meriphataud Mountains' },
    { id = 120, name = 'Sauromugue Champaign' },
    { id = 121, name = 'The Sanctuary of ZiTah' },
    { id = 122, name = 'RoMaeve' },
    { id = 123, name = 'Yuhtunga Jungle' },
    { id = 124, name = 'Yhoator Jungle' },
    { id = 125, name = 'Western Altepa Desert' },
    { id = 126, name = 'Qufim Island' },
    { id = 127, name = 'Behemoths Dominion' },
    { id = 128, name = 'Valley of Sorrows' },
    { id = 129, name = 'Ghoyus Reverie' },
    { id = 130, name = 'RuAun Gardens' },
    { id = 131, name = 'Mordion Gaol' },
    { id = 132, name = 'Abyssea-La Theine' },
    { id = 134, name = 'Dynamis-Beaucedine' },
    { id = 135, name = 'Dynamis-Xarcabard' },
    { id = 136, name = 'Beaucedine Glacier [S]' },
    { id = 137, name = 'Xarcabard [S]' },
    { id = 138, name = 'Castle Zvahl Baileys [S]' },
    { id = 139, name = 'Horlais Peak' },
    { id = 140, name = 'Ghelsba Outpost' },
    { id = 141, name = 'Fort Ghelsba' },
    { id = 142, name = 'Yughott Grotto' },
    { id = 143, name = 'Palborough Mines' },
    { id = 144, name = 'Waughroon Shrine' },
    { id = 145, name = 'Giddeus' },
    { id = 146, name = 'Balgas Dais' },
    { id = 147, name = 'Beadeaux' },
    { id = 148, name = 'Qulun Dome' },
    { id = 149, name = 'Davoi' },
    { id = 150, name = 'Monastic Cavern' },
    { id = 151, name = 'Castle Oztroja' },
    { id = 152, name = 'Altar Room' },
    { id = 153, name = 'The Boyahda Tree' },
    { id = 154, name = 'Dragons Aery' },
    { id = 155, name = 'Castle Zvahl Keep [S]' },
    { id = 156, name = 'Throne Room [S]' },
    { id = 157, name = 'Middle Delkfutts Tower' },
    { id = 158, name = 'Upper Delkfutts Tower' },
    { id = 159, name = 'Temple of Uggalepih' },
    { id = 160, name = 'Den of Rancor' },
    { id = 161, name = 'Castle Zvahl Baileys' },
    { id = 162, name = 'Castle Zvahl Keep' },
    { id = 163, name = 'Sacrificial Chamber' },
    { id = 164, name = 'Garlaige Citadel [S]' },
    { id = 165, name = 'Throne Room' },
    { id = 166, name = 'Ranguemont Pass' },
    { id = 167, name = 'Bostaunieux Oubliette' },
    { id = 168, name = 'Chamber of Oracles' },
    { id = 169, name = 'Toraimarai Canal' },
    { id = 170, name = 'Full Moon Fountain' },
    { id = 171, name = 'Crawlers Nest [S]' },
    { id = 172, name = 'Zeruhn Mines' },
    { id = 173, name = 'Korroloka Tunnel' },
    { id = 174, name = 'Kuftal Tunnel' },
    { id = 175, name = 'The Eldieme Necropolis [S]' },
    { id = 176, name = 'Sea Serpent Grotto' },
    { id = 177, name = 'VeLugannon Palace' },
    { id = 178, name = 'The Shrine of RuAvitau' },
    { id = 179, name = 'Stellar Fulcrum' },
    { id = 180, name = 'LaLoff Amphitheater' },
    { id = 181, name = 'The Celestial Nexus' },
    { id = 182, name = 'Walk of Echoes' },
    { id = 183, name = 'Maquette Abdhaljs-Legion' },
    { id = 184, name = 'Lower Delkfutts Tower' },
    { id = 185, name = 'Dynamis-San dOria' },
    { id = 186, name = 'Dynamis-Bastok' },
    { id = 187, name = 'Dynamis-Windurst' },
    { id = 188, name = 'Dynamis-Jeuno' },
    { id = 189, name = 'Residential Area' },
    { id = 190, name = 'King Ranperres Tomb' },
    { id = 191, name = 'Dangruf Wadi' },
    { id = 192, name = 'Inner Horutoto Ruins' },
    { id = 193, name = 'Ordelles Caves' },
    { id = 194, name = 'Outer Horutoto Ruins' },
    { id = 195, name = 'The Eldieme Necropolis' },
    { id = 196, name = 'Gusgen Mines' },
    { id = 197, name = 'Crawlers Nest' },
    { id = 198, name = 'Maze of Shakhrami' },
    { id = 199, name = 'Residential Area' },
    { id = 200, name = 'Garlaige Citadel' },
    { id = 201, name = 'Cloister of Gales' },
    { id = 202, name = 'Cloister of Storms' },
    { id = 203, name = 'Cloister of Frost' },
    { id = 204, name = 'FeiYin' },
    { id = 205, name = 'Ifrits Cauldron' },
    { id = 206, name = 'QuBia Arena' },
    { id = 207, name = 'Cloister of Flames' },
    { id = 208, name = 'Quicksand Caves' },
    { id = 209, name = 'Cloister of Tremors' },
    { id = 210, name = 'GM Home' },
    { id = 211, name = 'Cloister of Tides' },
    { id = 212, name = 'Gustav Tunnel' },
    { id = 213, name = 'Labyrinth of Onzozo' },
    { id = 214, name = 'Residential Area' },
    { id = 215, name = 'Abyssea-Attohwa' },
    { id = 216, name = 'Abyssea-Misareaux' },
    { id = 217, name = 'Abyssea-Vunkerl' },
    { id = 218, name = 'Abyssea-Altepa' },
    { id = 219, name = 'Residential Area' },
    { id = 220, name = 'Ship bound for Selbina' },
    { id = 221, name = 'Ship bound for Mhaura' },
    { id = 222, name = 'Provenance' },
    { id = 223, name = 'San dOria-Jeuno Airship' },
    { id = 224, name = 'Bastok-Jeuno Airship' },
    { id = 225, name = 'Windurst-Jeuno Airship' },
    { id = 226, name = 'Kazham-Jeuno Airship' },
    { id = 227, name = 'Ship bound for Selbina Pirates' },
    { id = 228, name = 'Ship bound for Mhaura Pirates' },
    { id = 230, name = 'Southern San dOria' },
    { id = 231, name = 'Northern San dOria' },
    { id = 232, name = 'Port San dOria' },
    { id = 233, name = 'Chateau dOraguille' },
    { id = 234, name = 'Bastok Mines' },
    { id = 235, name = 'Bastok Markets' },
    { id = 236, name = 'Port Bastok' },
    { id = 237, name = 'Metalworks' },
    { id = 238, name = 'Windurst Waters' },
    { id = 239, name = 'Windurst Walls' },
    { id = 240, name = 'Port Windurst' },
    { id = 241, name = 'Windurst Woods' },
    { id = 242, name = 'Heavens Tower' },
    { id = 243, name = 'RuLude Gardens' },
    { id = 244, name = 'Upper Jeuno' },
    { id = 245, name = 'Lower Jeuno' },
    { id = 246, name = 'Port Jeuno' },
    { id = 247, name = 'Rabao' },
    { id = 248, name = 'Selbina' },
    { id = 249, name = 'Mhaura' },
    { id = 250, name = 'Kazham' },
    { id = 251, name = 'Hall of the Gods' },
    { id = 252, name = 'Norg' },
    { id = 253, name = 'Abyssea-Uleguerand' },
    { id = 254, name = 'Abyssea-Grauberg' },
    { id = 255, name = 'Abyssea-Empyreal Paradox' },
    { id = 256, name = 'Western Adoulin' },
    { id = 257, name = 'Eastern Adoulin' },
    { id = 258, name = 'Rala Waterways' },
    { id = 259, name = 'Rala Waterways U' },
    { id = 260, name = 'Yahse Hunting Grounds' },
    { id = 261, name = 'Ceizak Battlegrounds' },
    { id = 262, name = 'Foret de Hennetiel' },
    { id = 263, name = 'Yorcia Weald' },
    { id = 264, name = 'Yorcia Weald U' },
    { id = 265, name = 'Morimar Basalt Fields' },
    { id = 266, name = 'Marjami Ravine' },
    { id = 267, name = 'Kamihr Drifts' },
    { id = 268, name = 'Sih Gates' },
    { id = 269, name = 'Moh Gates' },
    { id = 270, name = 'Cirdas Caverns' },
    { id = 271, name = 'Cirdas Caverns U' },
    { id = 272, name = 'Dho Gates' },
    { id = 273, name = 'Woh Gates' },
    { id = 274, name = 'Outer RaKaznar' },
    { id = 275, name = 'Outer RaKaznar U' },
    { id = 276, name = 'RaKaznar Inner Court' },
    { id = 277, name = 'RaKaznar Turris' },
    { id = 280, name = 'Mog Garden' },
    { id = 281, name = 'Leafallia' },
    { id = 282, name = 'Mount Kamihr' },
    { id = 283, name = 'Silver Knife' },
    { id = 284, name = 'Celennia Memorial Library' },
    { id = 285, name = 'Feretory' },
    { id = 288, name = 'Escha ZiTah' },
    { id = 289, name = 'Escha RuAun' },
    { id = 290, name = 'Desuetia Empyreal Paradox' },
    { id = 291, name = 'Reisenjima' },
    { id = 292, name = 'Reisenjima Henge' },
    { id = 293, name = 'Reisenjima Sanctorium' },
    { id = 294, name = 'Dynamis-San dOria [D]' },
    { id = 295, name = 'Dynamis-Bastok [D]' },
    { id = 296, name = 'Dynamis-Windurst [D]' },
    { id = 297, name = 'Dynamis-Jeuno [D]' },
}

-- Sort selectable zones by name
table.sort(selectableZones, function(a,b) return a.name < b.name end)

-- Prepare song list
local songOptions = {};
for id, data in pairs(zoneData) do
    if data.music > 0 then
        table.insert(songOptions, { id = data.music, label = string.format("[%d] %s", data.music, data.name) });
    end
end
table.sort(songOptions, function(a,b) return a.id < b.id end)

------------------------------------------------------------
-- UI Rendering
------------------------------------------------------------
ashita.events.register('d3d_present', 'present_cb', function ()
    if (not state.ui_open[1]) then return end

    imgui.SetNextWindowSize({ 450, 450 }, ImGuiCond_FirstUseEver);
    if (imgui.Begin('BGMBard Config', state.ui_open)) then
        
        imgui.Text('Note: Changes take place on zoning.');
        imgui.Separator();

        -- Override Section
        imgui.Text('Select Zone to Overwrite:');
        local preview_name = selectableZones[state.selected_target_idx] and selectableZones[state.selected_target_idx].name or "Select...";
        
        if (imgui.BeginCombo('##zone_select', preview_name)) then
            for i, zone in ipairs(selectableZones) do
                if (imgui.Selectable(string.format("%s (Zone ID: %d)", zone.name, zone.id), i == state.selected_target_idx)) then
                    state.selected_target_idx = i;
                end
            end
            imgui.EndCombo();
        end
        
        imgui.SameLine();
		if (imgui.Button('Add Override')) then
			local target_id = selectableZones[state.selected_target_idx].id;
			local id_str = tostring(target_id);
			if not music_settings.overrides[id_str] then
				-- Initializing all 5 slots to 0 (Original)
				music_settings.overrides[id_str] = { 
					day = 0, 
					night = 0, 
					solo = 0, 
					party = 0, 
					mount = 0 
				};
				settings.save();
			end
		end

		imgui.Separator();
        -- Global toggle for Advanced Mode
        if (imgui.Checkbox('Advanced Music Replace', { music_settings.advanced_mode })) then
            music_settings.advanced_mode = not music_settings.advanced_mode;
            settings.save();
        end
        imgui.Text('Active Overrides:');

        for z_id_str, cfg in pairs(music_settings.overrides) do
            local z_id = tonumber(z_id_str);
            local zone_name = "Unknown Zone";
            for _, v in ipairs(selectableZones) do if v.id == z_id then zone_name = v.name break end end
            
            if (imgui.TreeNode(string.format("%s (Zone ID: %d)##%d", zone_name, z_id, z_id))) then
                
			if (music_settings.advanced_mode) then
				-- Initialize buffers for all 5 slots if missing
				if not state.text_buffers[z_id_str] then
					state.text_buffers[z_id_str] = { 
						day = { tostring(cfg.day or 0) }, 
						night = { tostring(cfg.night or 0) },
						solo = { tostring(cfg.solo or 0) },
						party = { tostring(cfg.party or 0) },
						mount = { tostring(cfg.mount or 0) }
					}
				end

				-- Day/Night
				if (imgui.InputText('Day BGM##' .. z_id, state.text_buffers[z_id_str].day, 32)) then
					cfg.day = tonumber(state.text_buffers[z_id_str].day[1]) or 0; settings.save();
				end
				if (imgui.InputText('Night BGM##' .. z_id, state.text_buffers[z_id_str].night, 32)) then
					cfg.night = tonumber(state.text_buffers[z_id_str].night[1]) or 0; settings.save();
				end

				-- Extra Advanced Fields - Battle solo, party, and mount
				imgui.Separator();
				if (imgui.InputText('Battle: Solo##' .. z_id, state.text_buffers[z_id_str].solo, 32)) then
					cfg.solo = tonumber(state.text_buffers[z_id_str].solo[1]) or 0; settings.save();
				end
				if (imgui.InputText('Battle: Party##' .. z_id, state.text_buffers[z_id_str].party, 32)) then
					cfg.party = tonumber(state.text_buffers[z_id_str].party[1]) or 0; settings.save();
				end
				if (imgui.InputText('Mount Music##' .. z_id, state.text_buffers[z_id_str].mount, 32)) then
					cfg.mount = tonumber(state.text_buffers[z_id_str].mount[1]) or 0; settings.save();
				end
			else
                    --------------------------------------------------------
                    -- STANDARD MODE: Dropdowns
                    --------------------------------------------------------
                    -- Day Music Dropdown
                    local current_day_label = "Original";
                    for _, s in ipairs(songOptions) do if s.id == cfg.day then current_day_label = s.label end end
                    
                    if (imgui.BeginCombo('Day Music##' .. z_id, current_day_label)) then
                        if (imgui.Selectable('Original', cfg.day == 0)) then cfg.day = 0; settings.save(); end
                        for _, s in ipairs(songOptions) do
                            if (imgui.Selectable(s.label, cfg.day == s.id)) then
                                cfg.day = s.id;
                                settings.save();
                            end
                        end
                        imgui.EndCombo();
                    end

                    -- Night Music Dropdown
                    local current_night_label = "Original";
                    for _, s in ipairs(songOptions) do if s.id == cfg.night then current_night_label = s.label end end

                    if (imgui.BeginCombo('Night Music##' .. z_id, current_night_label)) then
                        if (imgui.Selectable('Original', cfg.night == 0)) then cfg.night = 0; settings.save(); end
                        for _, s in ipairs(songOptions) do
                            if (imgui.Selectable(s.label, cfg.night == s.id)) then
                                cfg.night = s.id;
                                settings.save();
                            end
                        end
                        imgui.EndCombo();
                    end
                end

                -- Delete Button
                imgui.PushStyleColor(ImGuiCol_Button, { 0.6, 0.1, 0.1, 1.0 });
                if (imgui.Button('Delete Override##' .. z_id)) then
                    music_settings.overrides[z_id_str] = nil;
                    state.text_buffers[z_id_str] = nil;
                end
                imgui.PopStyleColor();
                
                imgui.TreePop();
                imgui.Separator();
            end
        end
    end
    imgui.End();
end);

------------------------------------------------------------
-- Command & Packets
------------------------------------------------------------
ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    local cmd = args[1]:lower();
    if (cmd == '/bard' or cmd == '/bgm' or cmd == '/bgmbard') then
        state.ui_open[1] = not state.ui_open[1];
        e.blocked = true;
    end
end);

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if (e.id == 0x000A) then
        local packet = ffi.cast('GP_SERV_LOGIN*', e.data_modified_raw);
        local zone_id = packet.ZoneNo;
        local cfg = music_settings.overrides[tostring(zone_id)];

        if (cfg) then
            -- Index 0: Day
            if (cfg.day and cfg.day > 0) then packet.MusicNum[0] = cfg.day; end
            -- Index 1: Night
            if (cfg.night and cfg.night > 0) then packet.MusicNum[1] = cfg.night; end
            -- Index 2: Battle Solo
            if (cfg.solo and cfg.solo > 0) then packet.MusicNum[2] = cfg.solo; end
            -- Index 3: Battle Party
            if (cfg.party and cfg.party > 0) then packet.MusicNum[3] = cfg.party; end
            -- Index 4: Mount
            if (cfg.mount and cfg.mount > 0) then packet.MusicNum[4] = cfg.mount; end
        end
    end
end);