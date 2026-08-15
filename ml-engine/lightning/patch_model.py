#!/usr/bin/env python3
import sys
from pathlib import Path

def patch_locateanything(file_path: Path):
    if not file_path.exists():
        print(f"❌ File not found: {file_path}")
        return False
        
    content = file_path.read_text()
    
    # Check if already patched
    if "attention_mask = torch.ones" in content:
        print(f"ℹ️ {file_path.name} is already fully patched.")
        return True
        
    print(f"🔍 Patching {file_path}...")
    
    # 0. Patch MTP token truncation
    old_target_0 = """            out_pattern = handle_pattern(new_tokens, self.token_ids, generation_mode)
            out_type = out_pattern['type']
            out_token = torch.tensor(out_pattern['tokens'], dtype=x0.dtype, device=x0.device)"""
    new_replacement_0 = """            out_pattern = handle_pattern(new_tokens, self.token_ids, generation_mode)
            out_type = out_pattern['type']
            tokens = out_pattern['tokens']
            if out_type == 'ref_object':
                tokens = tokens[:1]
            out_token = torch.tensor(tokens, dtype=x0.dtype, device=x0.device)"""
            
    if old_target_0 in content:
        content = content.replace(old_target_0, new_replacement_0)
        print("  Patched pattern 0 (MTP token truncation)")
        
    # 1. Patch ref_end_token_id definition
    old_target_1 = """            box_end_token_id = self.token_ids['box_end_token_id']
            coord_start_token_id = self.token_ids['coord_start_token_id']
            coord_end_token_id = self.token_ids['coord_end_token_id']
            none_token_id = self.token_ids['none_token_id']
            im_end_token_id = self.token_ids['im_end_token_id']"""
    new_replacement_1 = old_target_1 + "\n            ref_end_token_id = self.token_ids['ref_end_token_id']"
    if old_target_1 in content and "ref_end_token_id = self.token_ids['ref_end_token_id']" not in content:
        content = content.replace(old_target_1, new_replacement_1)
        print("  Patched pattern 1 (ref_end_token_id definition)")

    # 2. Patch AR transition
    old_target_2 = """            if generation_mode == 'hybrid':
                # Hybrid AR phase: detect box boundaries to switch back to MTP
                if token_val == box_end_token_id:
                    out_type = 'box_end_ar'
                elif coord_start_token_id <= token_val <= coord_end_token_id or token_val == none_token_id:
                    out_type = 'coord_ar'
                else:
                    out_type = 'im_end'"""
    new_replacement_2 = """            if generation_mode == 'hybrid':
                # Hybrid AR phase: detect box boundaries to switch back to MTP
                if token_val == box_end_token_id:
                    out_type = 'box_end_ar'
                elif token_val == ref_end_token_id:
                    out_type = 'ref_end_ar'
                elif coord_start_token_id <= token_val <= coord_end_token_id or token_val == none_token_id:
                    out_type = 'coord_ar'
                else:
                    out_type = 'im_end'"""
    if old_target_2 in content:
        content = content.replace(old_target_2, new_replacement_2)
        print("  Patched pattern 2 (AR transition)")

    # 3. Patch generation loop switching
    old_target_3 = """            if generation_mode == 'hybrid':
                if out_type == 'error_box':
                    use_mtp = False
                    switch_to_ar_count += 1
                elif out_type == 'box_end_ar':
                    use_mtp = True"""
    new_replacement_3 = """            if generation_mode == 'hybrid':
                if out_type in ('error_box', 'ref_object'):
                    use_mtp = False
                    switch_to_ar_count += 1
                elif out_type in ('box_end_ar', 'ref_end_ar'):
                    use_mtp = True"""
    if old_target_3 in content:
        content = content.replace(old_target_3, new_replacement_3)
        print("  Patched pattern 3 (generation loop switching)")
        
    # 4. Patch prefill_time None value initialization bug
    old_target_4 = "        prefill_time = None"
    new_replacement_4 = "        prefill_time = 0.0"
    if old_target_4 in content:
        content = content.replace(old_target_4, new_replacement_4)
        print("  Patched pattern 4 (prefill_time default value)")
        
    # 5. Patch attention_mask passing in generation loop (crucial for newer transformers compatibility)
    old_target_5_mtp = """            prepare_inputs = self.language_model.prepare_inputs_for_generation(
                generated_with_mask,
                past_key_values,
                None,
                inputs_embeds=None,
                use_cache=True,
                position_ids=position_ids
            )"""
    new_replacement_5_mtp = """            attention_mask = torch.ones((generated_with_mask.shape[0], generated_with_mask.shape[1]), dtype=torch.long, device=generated.device)
            prepare_inputs = self.language_model.prepare_inputs_for_generation(
                generated_with_mask,
                past_key_values,
                attention_mask,
                inputs_embeds=None,
                use_cache=True,
                position_ids=position_ids
            )"""
            
    old_target_5_ar = """            prepare_inputs = self.language_model.prepare_inputs_for_generation(
                generated,
                past_key_values,
                None,
                inputs_embeds=None,
                use_cache=True,
                position_ids=position_ids
            )"""
    new_replacement_5_ar = """            attention_mask = torch.ones((generated.shape[0], generated.shape[1]), dtype=torch.long, device=generated.device)
            prepare_inputs = self.language_model.prepare_inputs_for_generation(
                generated,
                past_key_values,
                attention_mask,
                inputs_embeds=None,
                use_cache=True,
                position_ids=position_ids
            )"""
            
    if old_target_5_mtp in content:
        content = content.replace(old_target_5_mtp, new_replacement_5_mtp)
        print("  Patched pattern 5 MTP (attention_mask passing)")
    if old_target_5_ar in content:
        content = content.replace(old_target_5_ar, new_replacement_5_ar)
        print("  Patched pattern 5 AR (attention_mask passing)")
        
    file_path.write_text(content)
    print("✅ Successfully patched modeling_locateanything.py")
    return True

def patch_qwen2(file_path: Path):
    if not file_path.exists():
        print(f"❌ File not found: {file_path}")
        return False
        
    content = file_path.read_text()
    
    if "Recalculate inv_freq" in content:
        print(f"ℹ️ {file_path.name} is already patched.")
        return True
        
    print(f"🔍 Patching {file_path}...")
    
    old_target = """    def forward(self, x, seq_len=None):
        # x: [bs, num_attention_heads, seq_len, head_size]
        if seq_len > self.max_seq_len_cached:
            self._set_cos_sin_cache(seq_len=seq_len, device=x.device, dtype=x.dtype)

        return (
            self.cos_cached[:seq_len].to(dtype=x.dtype),
            self.sin_cached[:seq_len].to(dtype=x.dtype),
        )"""

    new_replacement = """    def forward(self, x, seq_len=None):
        # x: [bs, num_attention_heads, seq_len, head_size]
        # Recalculate inv_freq dynamically to avoid uninitialized memory NaNs from device_map='auto'
        device = x.device
        self.inv_freq = 1.0 / (self.base ** (torch.arange(0, self.dim, 2).float().to(device) / self.dim))
        if seq_len > self.max_seq_len_cached or self.cos_cached.device != device or torch.isnan(self.cos_cached).any():
            self._set_cos_sin_cache(seq_len=seq_len, device=device, dtype=x.dtype)

        return (
            self.cos_cached[:seq_len].to(dtype=x.dtype),
            self.sin_cached[:seq_len].to(dtype=x.dtype),
        )"""

    if old_target not in content:
        print("❌ Could not find target pattern in modeling_qwen2.py!")
        return False
        
    content = content.replace(old_target, new_replacement)
    file_path.write_text(content)
    print("✅ Successfully patched modeling_qwen2.py")
    return True

if __name__ == "__main__":
    cache_dir = Path("/teamspace/studios/this_studio/.cache/huggingface/modules/transformers_modules/nvidia/LocateAnything_hyphen_3B/c32291ca5e996f5a7a485845b4f57a233936bba0")
    
    la_path = cache_dir / "modeling_locateanything.py"
    qwen_path = cache_dir / "modeling_qwen2.py"
    
    success = True
    success &= patch_locateanything(la_path)
    success &= patch_qwen2(qwen_path)
    
    if success:
        sys.exit(0)
    else:
        sys.exit(1)
