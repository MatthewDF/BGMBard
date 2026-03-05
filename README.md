# BGM Bard by Mazu
<p align="center">
<img width="609" height="533" alt="image" src="https://github.com/user-attachments/assets/2ab54501-e9fe-45cd-b7d7-ac035e2b8a83" />
</p>

An Addon for having finer control over your music experience within Vana'diel, BGM Bard allows you to choose music for specific areas, including different songs for Day and Night, and Advanced options that allow you to select music for Battle and Mounts in a zone.

---

## Installation

Place BGMBard.lua in a folder of the same name within your HorizonXI\Game\addons folder, then add the addon to your default.txt in HorizonXI\Game\scripts.

In-game, be sure to type `/addon load BGMBard` to activate it for the first time, if needed.

## Use

In-game, type `/bgm`, `/bard`, or `/bgmbard` to open the interface. 

From the dropdown, select the zone you want to override music for, then `Add Override`.

Below, you'll see the zone added with Day and Night music options. The number in [brackets] is the song ID, and the zones names beside it are the zones that use that song. 

<img width="536" height="266" alt="image" src="https://github.com/user-attachments/assets/fcbadea1-d76f-46cf-9fac-b45e7ac7f3e1" />

## Advanced Music Replace

<img width="608" height="248" alt="image" src="https://github.com/user-attachments/assets/6b4764ca-0bf7-4b27-b3c8-9e2f96f003ff" />

In this mode you can instead manually type in any 3-digit song id (otherwise known as the .bgw file number), and BGMBard will use that song instead. This gives you even more control over what songs are played, but it doesn't have a pre-populated list of songs to pick from.

## Known Issues
- If using UniquePets, there is a delay in loading settings for addons that causes neither to load their saved settings. Reload both addons with /addon reload, and this will fix it.
