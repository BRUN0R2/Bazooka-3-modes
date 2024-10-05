#include <amxmodx>
#include <fakemeta_util>
#include <hamsandwich>
#include <reapi>
#include <rezp_inc/rezp_main>
#include <rezp_inc/api/api_player_camera>
#pragma compress 1

#define PLUGIN  "[REAPI] Weapon: Bazooka"
#define VERSION "1.0"
#define AUTHOR  "BRUN0"

new const V_WEAPON_MODEL[] = "models/rezombie/weapons/bazooka/model_v.mdl"
new const P_WEAPON_MODEL[] = "models/rezombie/weapons/bazooka/model_p.mdl"
new const W_WEAPON_MODEL[] = "models/rezombie/weapons/bazooka/model_w.mdl"
new const S_WEAPON_ROCKET[]= "models/rezombie/weapons/bazooka/rocket.mdl"

new const WEAPON_SOUNDS[][]=
{
	"rezombie/weapons/bazooka/fire.wav",	// 00
	"rezombie/weapons/bazooka/fly.wav",		// 01
	"rezombie/weapons/bazooka/exp.wav", 	// 02
	"rezombie/weapons/bazooka/draw.wav", 	// 03
	"rezombie/weapons/bazooka/clipin1.wav",	// 04
	"rezombie/weapons/bazooka/clipin2.wav",	// 05
	"rezombie/weapons/bazooka/clipin3.wav",	// 06
	"common/wpn_select.wav",				// 07
};

// 0 = male hand
// 1 = female hand
const WEAPON_BODY = 1 // This works well :)
const WEAPON_CLIP = 1
const WEAPON_AMMO = 40
const WEAPON_SLOT = 1

const Float:WEAPON_RELOAD_TIME = 3.8
const Float:WEAPON_IDLE_TIME = 3.5
const Float:WEAPON_DEPLOY_TIME = 1.1
const Float:WEAPON_PRIMARYATTACK = 1.0
const Float:WEAPON_SECONDARYATTACK = 0.3

const Float:WEAPON_NORMAL_SPEED = 2000.0
const Float:WEAPON_HOAMING_SPEED = 720.0
const Float:WEAPON_CAMERA_SPEED = 520.0

const Float:WEAPON_MAX_DAMAGE = 2100.0
const Float:WEAPON_DMG_RADIUS = 450.0

const WeaponIdType:WEAPON_ID = WEAPON_GALIL
new const WEAPON_REFERENCE[] = "weapon_galil"
new const WEAPON_EXTENSION[] = "grenade"
new const WEAPON_WEAPOLIST[] = "rezombie/weapons/bazooka/hud"

const ENTITY_INTOLERANCE = 100

enum _:WeaponAnim
{
	ANIM_IDLE = 0,
	ANIM_SHOT1,
	ANIM_RELOAD,
	ANIM_DRAW,
	ANIM_DUMMY,
};

enum _:WeaponStates
{
	STATE_CAMERA,
	STATE_HOAMING,
	STATE_NORMAL,
};

new gl_pWeaponImpulse,
	gl_pMaxEntities,
	g_pModelIndexSmoke,
	g_pModelIndexFireball2,
	g_pModelIndexFireball3;

new Float:g_NextPlayerUpdate[MAX_PLAYERS + 1]
new pControlling[MAX_PLAYERS + 1]

public plugin_precache()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	rz_add_translate("weapons/bazooka3modes")

	gl_pMaxEntities = global_get(glb_maxEntities)

	new pWeapon = gl_pWeaponImpulse = rz_weapon_create("weapon_bazooka", WEAPON_REFERENCE)

	set_weapon_var(pWeapon, RZ_WEAPON_NAME, "RZ_WEAPON_BAZOOKA_NAME")
	set_weapon_var(pWeapon, RZ_WEAPON_SHORT_NAME, "RZ_WEAPON_BAZOOKA_SHORT")

	set_weapon_var(pWeapon, RZ_WEAPON_VIEW_MODEL, V_WEAPON_MODEL)
	set_weapon_var(pWeapon, RZ_WEAPON_PLAYER_MODEL, P_WEAPON_MODEL)
	set_weapon_var(pWeapon, RZ_WEAPON_WORLD_MODEL, W_WEAPON_MODEL)
	set_weapon_var(pWeapon, RZ_WEAPON_WEAPONLIST, WEAPON_WEAPOLIST)

	precache_model(S_WEAPON_ROCKET)

	for (new IND = 0; IND < sizeof WEAPON_SOUNDS; IND++) { 
		precache_sound(WEAPON_SOUNDS[IND])
	}

	g_pModelIndexSmoke = precache_model("sprites/steam1.spr")
	g_pModelIndexFireball2 = precache_model("sprites/eexplo.spr")
	g_pModelIndexFireball3 = precache_model("sprites/fexplo.spr")
}

public plugin_init()
{
	register_forward(FM_UpdateClientData, "@FM_Player_Update_Data_Post", true)
	RegisterHookChain(RG_CBasePlayer_Observer_IsValidTarget, "@CBasePlayer_Observer_IsValidTarget_Post", .post = true)
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "@CBasePlayerWeapon_DefaultDeploy_Pre", .post = false);
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "@CBasePlayerWeapon_DefaultReload_Pre", .post = false)
	RegisterHookChain(RG_CBasePlayerWeapon_SendWeaponAnim, "@CBasePlayerWeapon_SendWeaponAnim_Pre", .post = false);
	//RegisterHookChain(RG_CSGameRules_SendDeathMessage, "@CSGameRules_SendDeathMessage_Pre", .post = false);

	RegisterHam(Ham_Spawn,					WEAPON_REFERENCE,	"@HamHook_Weapon_Spawn_Post", .Post = true)
	RegisterHam(Ham_Item_ItemSlot,			WEAPON_REFERENCE,	"@HamHook_Weapon_Slot_Pre", .Post = false)
	RegisterHam(Ham_Item_AttachToPlayer,	WEAPON_REFERENCE,	"@HamHookWeapon_AttachToPlayer_Post", .Post = true)
	RegisterHam(Ham_Weapon_WeaponIdle,		WEAPON_REFERENCE,	"@HamHook_Weapon_WeaponIdle_Pre", .Post = false)
	RegisterHam(Ham_Weapon_PrimaryAttack,	WEAPON_REFERENCE,	"@HamHook_Weapon_PrimaryAttack_Pre", .Post = false)
	RegisterHam(Ham_Weapon_SecondaryAttack,	WEAPON_REFERENCE,	"@HamHook_Weapon_SecondaryAttack_Pre", .Post = false)
}

public client_putinserver(id) {
	pControlling[id] = false
}

public rz_class_change_pre(id, attacker, class) {
	@Player_reset_camera(id)
}
// I still don't know how it works
/*@CSGameRules_SendDeathMessage_Pre(const pKiller, const pVictim, const pAssister, const pevInflictor, const killerWeaponName[], const DeathMessageFlags:iDeathMessageFlags, const KillRarity:iRarityOfKill)
{
	if (!rz_is_weapon_valid(pevInflictor, .impulse = gl_pWeaponImpulse)) {
		return HC_CONTINUE
	}

	SetHookChainArg(5, ATYPE_STRING, "Bazooka")

	//rg_send_death_message(pKiller, pVictim, pAssister, pevInflictor, "Bazooka", iDeathMessageFlags, iRarityOfKill);
	return HC_CONTINUE
}*/

@FM_Player_Update_Data_Post(const id, const send_weapons, const cd_handle) 
{
	if (!is_user_connected(id)) {
		return FMRES_IGNORED
	}

	static pTarget, xActiveItem
	pTarget = (get_entvar(id, var_iuser1)) ? get_entvar(id, var_iuser2) : id

	if (!is_user_alive(pTarget)) {
		return FMRES_IGNORED
	}

	static Float:pGameTime; pGameTime = get_gametime()

	xActiveItem = get_member(pTarget, m_pActiveItem)
	if (!rz_is_weapon_valid(xActiveItem, .impulse = gl_pWeaponImpulse)) {
		return FMRES_IGNORED
	}

	if (!is_user_alive(id) && g_NextPlayerUpdate[id] && g_NextPlayerUpdate[id] <= pGameTime)
	{
		rg_weapon_send_animation(xActiveItem, ANIM_IDLE)
		g_NextPlayerUpdate[id] = 0.0
	}

	set_cd(cd_handle, CD_flNextAttack, pGameTime + 1.0)

	static Float:flLastEventCheck; flLastEventCheck = get_member(xActiveItem, m_flLastEventCheck)

	if (!flLastEventCheck) {
		set_cd(cd_handle, CD_WeaponAnim, ANIM_DUMMY) // Dummy
		return FMRES_IGNORED
	}

	if (flLastEventCheck <= pGameTime) {
		set_member(xActiveItem, m_flLastEventCheck, 0.0)
		rg_weapon_send_animation(xActiveItem, ANIM_DRAW)
	}

	return FMRES_IGNORED
}

@CBasePlayer_Observer_IsValidTarget_Post(const eObserver, const eTarget, bool:bSameTeam)
{
	if (GetHookChainReturn(ATYPE_INTEGER) != eTarget) {
		return HC_CONTINUE
	}

	new pActiveItem = get_member(eTarget, m_pActiveItem)
	if (is_nullent(pActiveItem))
		return HC_CONTINUE

	if (!rz_is_weapon_valid(pActiveItem, .impulse = gl_pWeaponImpulse)) {
		return HC_CONTINUE
	}

	g_NextPlayerUpdate[eObserver] = get_gametime() + 0.1
	return HC_CONTINUE
}

@CBasePlayerWeapon_DefaultDeploy_Pre(const pWeapon, szViewModel[], szWeaponModel[], iAnim, szAnimExt[], skiplocal)
{
	if (get_member(pWeapon, m_iId) != WEAPON_ID) {
		return HC_CONTINUE
	}

	if (!rz_is_weapon_valid(pWeapon, .impulse = gl_pWeaponImpulse)) {
		return HAM_IGNORED
	}

	set_entvar(pWeapon, var_body, WEAPON_BODY)

	set_member(pWeapon, m_flLastEventCheck, get_gametime() + 0.1)
	SetHookChainArg(4, ATYPE_INTEGER, ANIM_DUMMY)

	SetHookChainArg(5, ATYPE_STRING, WEAPON_EXTENSION)
	SetHookChainArg(6, ATYPE_INTEGER, 0)

	set_member(pWeapon, m_Weapon_flTimeWeaponIdle, WEAPON_DEPLOY_TIME)
	set_member(pWeapon, m_Weapon_flNextPrimaryAttack, WEAPON_DEPLOY_TIME)
	set_member(pWeapon, m_Weapon_flNextSecondaryAttack, WEAPON_DEPLOY_TIME)

	return HC_CONTINUE;
}

@CBasePlayerWeapon_DefaultReload_Pre(const pWeapon, iClipSize, animation, Float:fDelay)
{
	if (get_member(pWeapon, m_iId) != WEAPON_ID) {
		return HC_CONTINUE
	}

	if (!rz_is_weapon_valid(pWeapon, .impulse = gl_pWeaponImpulse)) {
		return HC_CONTINUE
	}

	if (get_member(pWeapon, m_Weapon_iClip) >= WEAPON_CLIP) {
		return HC_CONTINUE
	}

	SetHookChainArg(2, ATYPE_INTEGER, WEAPON_CLIP)
	SetHookChainArg(3, ATYPE_INTEGER, ANIM_RELOAD)
	SetHookChainArg(4, ATYPE_FLOAT, WEAPON_RELOAD_TIME)

	new pPlayer = get_member(pWeapon, m_pPlayer)

	set_member(pPlayer, m_szAnimExtention, "m249")
	rg_set_animation(pPlayer, PLAYER_RELOAD)

	// Fixed bug 0 ammo in the hud, 1 does not appear
	set_member(pWeapon, m_Weapon_flNextPrimaryAttack, WEAPON_RELOAD_TIME + 0.2)

	return HC_CONTINUE
}

@CBasePlayerWeapon_SendWeaponAnim_Pre(const pWeapon, iAnim, skiplocal)
{
	if (get_member(pWeapon, m_iId) != WEAPON_ID) {
		return HC_CONTINUE
	}
	if (!rz_is_weapon_valid(pWeapon, .impulse = gl_pWeaponImpulse)) {
		return HC_CONTINUE
	}
	rz_send_weapon_animation(pWeapon, get_member(pWeapon, m_pPlayer), iAnim)
	return HC_SUPERCEDE
}

@HamHook_Weapon_Spawn_Post(const pWeapon)
{
	if (!rz_is_weapon_valid(pWeapon, .impulse = gl_pWeaponImpulse)) {
		return HAM_IGNORED
	}

	new WeaponIdType:weaponId = get_member(pWeapon, m_iId);

	set_member(pWeapon, m_Weapon_iClip, WEAPON_CLIP)
	set_member(pWeapon, m_Weapon_iDefaultAmmo, WEAPON_AMMO)
	set_member(pWeapon, m_Weapon_bHasSecondaryAttack, true)

	set_member(pWeapon, m_Weapon_iWeaponState, STATE_NORMAL)

	rg_set_iteminfo(pWeapon, ItemInfo_iMaxClip, WEAPON_CLIP)
	rg_set_iteminfo(pWeapon, ItemInfo_iMaxAmmo1, WEAPON_AMMO)
	rg_set_iteminfo(pWeapon, ItemInfo_iSlot, WEAPON_SLOT - 1)
	rg_set_weapon_info(weaponId, WI_MAX_ROUNDS, WEAPON_AMMO)

	return HAM_IGNORED
}

@HamHook_Weapon_Slot_Pre(const pWeapon)
{
	if (!rz_is_weapon_valid(pWeapon, .impulse = gl_pWeaponImpulse)) {
		return HAM_IGNORED
	}

	SetHamReturnInteger(WEAPON_SLOT)
	return HAM_OVERRIDE
}

@HamHookWeapon_AttachToPlayer_Post(const pWeapon)
{
	if (!rz_is_weapon_valid(pWeapon, .impulse = gl_pWeaponImpulse)) {
		return HAM_IGNORED
	}

	set_member(pWeapon, m_Weapon_iWeaponState, STATE_NORMAL)
	rg_set_iteminfo(pWeapon, ItemInfo_iId, WEAPON_ID)
	return HAM_IGNORED
}

@HamHook_Weapon_WeaponIdle_Pre(const pWeapon)
{
	if (!rz_is_weapon_valid(pWeapon, .impulse = gl_pWeaponImpulse)) {
		return HAM_IGNORED
	}

	ExecuteHamB(Ham_Weapon_ResetEmptySound, pWeapon)
	if (Float:get_member(pWeapon, m_Weapon_flTimeWeaponIdle) >= 0.0) {
		return HAM_IGNORED
	}

	new pPlayer = get_member(pWeapon, m_pPlayer)
	set_member(pPlayer, m_szAnimExtention, WEAPON_EXTENSION)

	rg_weapon_send_animation(pWeapon, ANIM_IDLE)
	set_member(pWeapon, m_Weapon_flTimeWeaponIdle, WEAPON_IDLE_TIME)

	return HAM_SUPERCEDE
}

@HamHook_Weapon_PrimaryAttack_Pre(const pWeapon)
{
	if (!rz_is_weapon_valid(pWeapon, .impulse = gl_pWeaponImpulse)) {
		return HAM_IGNORED
	}

	new pWeaponClip = get_member(pWeapon, m_Weapon_iClip)
	new pPlayer = get_member(pWeapon, m_pPlayer)

	if (pWeaponClip <= 0) {
		ExecuteHamB(Ham_Weapon_PlayEmptySound, pWeapon)
		set_member(pWeapon, m_Weapon_flNextPrimaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	set_member(pWeapon, m_Weapon_iClip, --pWeaponClip)
	rh_emit_sound2(pPlayer, 0, CHAN_WEAPON, WEAPON_SOUNDS[0])
	rg_weapon_kickback(pWeapon, 12.0, 12.0, 12.0, 15.0, 20.0, 20.0, 1)

	rg_weapon_send_animation(pWeapon, ANIM_SHOT1)

	@Create_missile_entity(pWeapon, pPlayer)

	set_member(pPlayer, m_szAnimExtention, "knife")
	rg_set_animation(pPlayer, PLAYER_ATTACK1)

	set_member(pWeapon, m_Weapon_flNextPrimaryAttack, WEAPON_PRIMARYATTACK)
	set_member(pWeapon, m_Weapon_flNextSecondaryAttack, WEAPON_SECONDARYATTACK)
	set_member(pWeapon, m_Weapon_flTimeWeaponIdle, 2.0)

	return HAM_SUPERCEDE
}

@HamHook_Weapon_SecondaryAttack_Pre(const pWeapon)
{
	if (!rz_is_weapon_valid(pWeapon, .impulse = gl_pWeaponImpulse)) {
		return HAM_IGNORED
	}

	new pPlayer = get_member(pWeapon, m_pPlayer)

	if (get_member(pWeapon, m_Weapon_iClip) <= 0) {
		return HAM_SUPERCEDE
	}

	new pWeaponState = get_member(pWeapon, m_Weapon_iWeaponState)

	switch (WeaponStates:pWeaponState)
	{
		case STATE_CAMERA:
		{
			engclient_print(pPlayer, engprint_center, "[Mode : Hoaming]")
			pWeaponState = STATE_HOAMING
		}
		case STATE_HOAMING:
		{
			engclient_print(pPlayer, engprint_center, "[Mode : Normal]")
			pWeaponState = STATE_NORMAL
		}
		case STATE_NORMAL:
		{
			engclient_print(pPlayer, engprint_center, "[Mode : Camera]")
			pWeaponState = STATE_CAMERA
		}
	}

	@Player_reset_camera(pPlayer)

	set_member(pWeapon, m_Weapon_iWeaponState, pWeaponState)
	rh_emit_sound2(pPlayer, pPlayer, CHAN_WEAPON, WEAPON_SOUNDS[7])

	set_member(pWeapon, m_Weapon_flNextPrimaryAttack, 0.2)
	set_member(pWeapon, m_Weapon_flNextSecondaryAttack, WEAPON_SECONDARYATTACK)

	return HAM_SUPERCEDE
}

@Create_missile_entity(const pWeapon, const pPlayer) {
	if (gl_pMaxEntities - engfunc(EngFunc_NumberOfEntities) <= ENTITY_INTOLERANCE) {
		return
	}

	if (!is_user_alive(pPlayer))
		return

	new pMissile = rg_create_entity("info_target")
	if (is_nullent(pMissile)) {
		return
	}

	new Float:pVecSrc[3]; ExecuteHamB(Ham_Player_GetGunPosition, pPlayer, pVecSrc)
	new Float:vecDirect[3]; rz_util_get_vector_aiming(pPlayer, vecDirect)

	xs_vec_add_scaled(pVecSrc, vecDirect, 15.0, pVecSrc)

	set_entvar(pMissile, var_classname, "ent_rocket")
	set_entvar(pMissile, var_solid, SOLID_BBOX)
	set_entvar(pMissile, var_movetype, MOVETYPE_FLYMISSILE)
	set_entvar(pMissile, var_dmg_inflictor, pWeapon)
	set_entvar(pMissile, var_owner, pPlayer)

	engfunc(EngFunc_SetOrigin, pMissile, pVecSrc)
	engfunc(EngFunc_SetModel, pMissile, S_WEAPON_ROCKET)
	engfunc(EngFunc_SetSize, pMissile, {-1.0, -1.0, -1.0}, {1.0, 1.0, 1.0});

	xs_vec_mul_scalar(vecDirect, WEAPON_NORMAL_SPEED, vecDirect)
	set_entvar(pMissile, var_velocity, vecDirect)

	engfunc(EngFunc_VecToAngles, vecDirect, vecDirect)
	set_entvar(pMissile, var_angles, vecDirect)

	rh_emit_sound2(pMissile, 0, CHAN_WEAPON, WEAPON_SOUNDS[1])

	set_entvar(pMissile, var_effects, EF_BRIGHTLIGHT)

	if (get_member(pWeapon, m_Weapon_iWeaponState) == STATE_CAMERA) {
		breaks_player_camera(pPlayer)
		engset_view(pPlayer, pMissile)
		pControlling[pPlayer] = true
	}

	SetTouch(pMissile, "@Missile_entity_touch")
	SetThink(pMissile, "@Missile_entity_think")

	rz_util_te_beamfollow(pMissile, g_pModelIndexSmoke, 7, 1, {255, 255, 255, 255});

	set_entvar(pMissile, var_nextthink, get_gametime() + 0.08);
}

@Missile_entity_think(const pMissile)
{
	if (is_nullent(pMissile))
		return

	static pWeapon; pWeapon = get_entvar(pMissile, var_dmg_inflictor)
	if (is_nullent(pWeapon))
		return

	static pPlayer; pPlayer = get_entvar(pMissile, var_owner)
	switch (WeaponStates:get_member(pWeapon, m_Weapon_iWeaponState))
	{
		case STATE_CAMERA: {
			@Missile_camera_think(pMissile, pPlayer)
		}
		case STATE_HOAMING: {
			@Missile_hoaming_think(pMissile, pPlayer)
		}
	}
	// You must have 500 FPS+, don't touch here :)
	set_entvar(pMissile, var_nextthink, get_gametime() + 0.01)
}

@Missile_camera_think(const pMissile, const pPlayer)
{
	static Float:pVecAngle[3], Float:pVelocity[3], Float:pForward[3]

	get_entvar(pPlayer, var_v_angle, pVecAngle)
	angle_vector(pVecAngle, ANGLEVECTOR_FORWARD, pForward)

	pVelocity[0] = pForward[0] * WEAPON_CAMERA_SPEED
	pVelocity[1] = pForward[1] * WEAPON_CAMERA_SPEED
	pVelocity[2] = pForward[2] * WEAPON_CAMERA_SPEED

	set_entvar(pMissile, var_velocity, pVelocity)
	set_entvar(pMissile, var_angles, pVecAngle)
}

@Missile_hoaming_think(const pMissile, const pPlayer)
{
	static pTarget; pTarget = find_entity_target(pMissile, pPlayer)
	entity_follow_and_aim_target(pMissile, pTarget, WEAPON_HOAMING_SPEED)
}

stock entity_follow_and_aim_target(const pEntity, const pTarget, Float:pSpeed)
{
    if (is_nullent(pEntity) || is_nullent(pTarget)) return

    static Float:EntOrigin[3], Float:VicOrigin[3], Float:fl_Velocity[3],
	Float:direction[3], Float:NewAngle[3];

    rz_util_get_entity_center(pEntity, EntOrigin)
    rz_util_get_entity_center(pTarget, VicOrigin)

    direction[0] = VicOrigin[0] - EntOrigin[0] // Direção X
    direction[1] = VicOrigin[1] - EntOrigin[1] // Direção Y
    direction[2] = VicOrigin[2] - EntOrigin[2] // Direção Z

    xs_vec_normalize(direction, direction)

    fl_Velocity[0] = direction[0] * pSpeed
    fl_Velocity[1] = direction[1] * pSpeed
    fl_Velocity[2] = direction[2] * pSpeed

    set_entvar(pEntity, var_velocity, fl_Velocity)

    // Converter para graus
    NewAngle[0] = floatatan2(direction[2], vector_length(direction), radian) * (180.0 / M_PI) // Pitch
    NewAngle[1] = floatatan2(direction[1], direction[0], radian) * (180.0 / M_PI)   // Yaw
    NewAngle[2] = 0.0                       // Roll

    set_entvar(pEntity, var_angles, NewAngle)
}

@Missile_entity_touch(const pMissile)
{
	if (is_nullent(pMissile))
		return

	SetTouch(pMissile, NULL_STRING)
	SetThink(pMissile, NULL_STRING)

	set_entvar(pMissile, var_solid, SOLID_NOT)

	new Float:pVelocity[3]
	get_entvar(pMissile, var_velocity, pVelocity)
	xs_vec_normalize(pVelocity, pVelocity);

	new Float:pOrigin[3]
	get_entvar(pMissile, var_origin, pOrigin)

	new Float:pVecSpot[3]
	xs_vec_sub_scaled(pOrigin, pVelocity, 32.0, pVecSpot)

	new Float:pVecDest[3]
	xs_vec_add_scaled(pVecSpot, pVelocity, 64.0, pVecDest)

	new pTrace = create_tr2()
	engfunc(EngFunc_TraceLine, pVecSpot, pVecDest, IGNORE_MONSTERS, pMissile, pTrace)

	new Float:pFraction
	get_tr2(pTrace, TR_flFraction, pFraction)

	new Float:pEndPos[3]
	get_tr2(pTrace, TR_vecEndPos, pEndPos)

	new Float:pPlaneNormal[3]
	get_tr2(pTrace, TR_vecPlaneNormal, pPlaneNormal)

	if (pFraction != 1.0) for (new i = 0; i < 3; i++) {
		pOrigin[i] = pEndPos[i] + (pPlaneNormal[i] * (100 - 24.0) * 0.6)
	}

	pOrigin[2] + 20.0
	rz_util_te_explosion(pOrigin, g_pModelIndexFireball3, 25, 30, TE_EXPLFLAG_NOSOUND)

	pOrigin[0] + random_float(-64.0, 64.0)
	pOrigin[1] + random_float(-64.0, 64.0)
	pOrigin[2] + random_float(30.0, 35.0)

	rz_util_te_explosion(pOrigin, g_pModelIndexFireball2, 30, 30, TE_EXPLFLAG_NOSOUND)

	if (random_float(0.0, 1.0) < 0.5)
		rg_decal_trace(pTrace, DECAL_SCORCH1)
	else
		rg_decal_trace(pTrace, DECAL_SCORCH2)

	free_tr2(pTrace)

	new pWeapon = get_entvar(pMissile, var_dmg_inflictor)
	new pPlayer = get_entvar(pMissile, var_owner)

	if (is_nullent(pWeapon)) {
		rg_remove_entity(pMissile)
		return
	}

	new Float:pSkyOrigin[3]; get_entvar(pMissile, var_origin, pSkyOrigin)
	if (engfunc(EngFunc_PointContents, pSkyOrigin) == CONTENTS_SKY) {
		rg_remove_entity(pMissile)
		return
	}

	if (!is_user_connected(pPlayer)) {
		pPlayer = 0
		set_entvar(pMissile, var_owner, pPlayer)
	}

	if (!is_user_alive(pPlayer) && pControlling[pPlayer]) {
		pControlling[pPlayer] = false
	}

	rh_emit_sound2(pMissile, 0, CHAN_WEAPON, "common/null.wav")
	rh_emit_sound2(pMissile, 0, CHAN_STATIC, WEAPON_SOUNDS[2])

	set_entvar(pMissile, var_effects, get_entvar(pMissile, var_effects) | EF_NODRAW)
	SetThink(pMissile, "@Create_Smoke3_Effect")
	set_entvar(pMissile, var_velocity, NULL_VECTOR)
	set_entvar(pMissile, var_nextthink, get_gametime() + 0.55)

	@Player_reset_camera(pPlayer)

	Create_bazooka_damage(
		pMissile,
		pWeapon,
		pPlayer,
		WEAPON_DMG_RADIUS,
		WEAPON_MAX_DAMAGE,
		DMG_BURN|DMG_NEVERGIB
	)
}

stock Create_bazooka_damage(const pEntity, const pWeapon, const pPlayer, const Float:pDamageRadius, const Float:pMaxDamage, const pDmgType = DMG_GENERIC)
{
	for (new pTarget = 1; pTarget <= engfunc(EngFunc_NumberOfEntities); pTarget++)
	{
		if (get_entvar(pTarget, var_takedamage) == DAMAGE_NO)
			continue;

		new Float:pRange = rz_util_entity_range(pEntity, pTarget)
		new Float:pDamage = pMaxDamage * (1.0 - (pRange / pDamageRadius))

		if (pRange >= pDamageRadius)
			continue;

		if (!is_nullent(pTarget) && is_user_alive(pTarget))
		{
			if (!is_valid_enemy(pTarget, pPlayer))
				continue;

			set_member(pTarget, m_LastHitGroup, HIT_GENERIC)

			rg_multidmg_clear()
			rg_multidmg_add(pWeapon, pTarget, pDamage, pDmgType)
			rg_multidmg_apply(pWeapon, pPlayer)
		}
		// Damage to entities
		else if (!is_nullent(pTarget)) {
			rg_multidmg_clear()
			rg_multidmg_add(pWeapon, pTarget, pDamage, pDmgType)
			rg_multidmg_apply(pWeapon, pPlayer)
		}
	}
}

@Create_Smoke3_Effect(const pEntity)
{
	SetThink(pEntity, NULL_STRING)
	new Float:pOrigin[3]; get_entvar(pEntity, var_origin, pOrigin)
	rz_util_te_smoke(pOrigin, g_pModelIndexSmoke, 35 + random_num(0, 10), 15)
	rg_remove_entity(pEntity)
}

stock find_entity_target(const pEntity, const pPlayer, const Float:pRange = 7999.9)
{
	new Float:closestDistance = pRange;
	new pClosestEnemy = NULLENT;

	for (new pTarget = 1; pTarget <= engfunc(EngFunc_NumberOfEntities); pTarget++)
	{
		if (get_entvar(pTarget, var_takedamage) == DAMAGE_NO)
			continue;

		if (!rz_util_entity_visible(pEntity, pTarget))
			continue;

		new Float:pDistance = rz_util_entity_range(pEntity, pTarget);

		if (!is_user_alive(pTarget))
			continue;

		if (!is_valid_enemy(pTarget, pPlayer))
			continue;

		if (pDistance < closestDistance) {
			closestDistance = pDistance;
			pClosestEnemy = pTarget;
		}
	}

	return pClosestEnemy;
}

stock bool:is_valid_enemy(const pTarget, const pPlayer)
{
	if (GetProtectionState(pTarget))
		return false

	if (rz_util_similar_team(pTarget, pPlayer))
		return false

	if (!rg_is_player_can_takedamage(pTarget, pPlayer))
		return false

	return true
}

@Player_reset_camera(const pPlayer) {
	if (is_user_alive(pPlayer) && pControlling[pPlayer])
	{
		if (get_camera_have(pPlayer)) {
			create_player_camera(pPlayer)
			return
		}

		engset_view(pPlayer, pPlayer)
		pControlling[pPlayer] = false
	}
}