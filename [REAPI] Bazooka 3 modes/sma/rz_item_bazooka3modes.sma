#include <amxmodx>
#include <reapi>
#include <rezp_inc/rezp_main>
#pragma compress 1

new g_iClass_Human
new gl_pWeaponImpulse
new gl_pItem_Index

public plugin_precache()
{
	register_plugin("[ReZP] Item: Bazooka", REZP_VERSION_STR, "BRUN0")

	RZ_CHECK_CLASS_EXISTS(g_iClass_Human, "class_human");
	RZ_CHECK_WEAPON_EXISTS(gl_pWeaponImpulse, "weapon_bazooka");

	rz_add_translate("weapons/bazooka3modes")

	new pItem = gl_pItem_Index = rz_item_create("item_bazooka3")

	rz_item_set(pItem, RZ_ITEM_NAME, "RZ_ITEM_WPN_BAZOOKA")
	rz_item_set(pItem, RZ_ITEM_COST, 90);
	rz_item_command_add(pItem, "say /bazooka3")
}

public rz_items_select_pre(id, pItem)
{
	if (pItem != gl_pItem_Index)
		return RZ_CONTINUE

	if (rz_player_get(id, RZ_PLAYER_CLASS) != g_iClass_Human)
		return RZ_BREAK

	new handle[RZ_MAX_HANDLE_LENGTH]
	get_weapon_var(gl_pWeaponImpulse, RZ_WEAPON_HANDLE, handle, charsmax(handle))

	if (rz_find_weapon_by_handler(id, handle)) {
		return RZ_SUPERCEDE
	}

	return RZ_CONTINUE
}

public rz_items_select_post(id, pItem)
{
	if (pItem != gl_pItem_Index)
		return

	new reference[RZ_MAX_REFERENCE_LENGTH]
	get_weapon_var(gl_pWeaponImpulse, RZ_WEAPON_REFERENCE, reference, charsmax(reference))
	new pWeapon = rg_give_custom_item(id, reference, GT_REPLACE, gl_pWeaponImpulse)

	if (!is_nullent(pWeapon)) {
		new WeaponIdType:weaponId = get_member(pWeapon, m_iId);
		set_member(id, m_rgAmmo, rg_get_weapon_info(weaponId, WI_MAX_ROUNDS), rg_get_weapon_info(weaponId, WI_AMMO_TYPE))
		rg_switch_weapon(id, pWeapon)
	}
}