let ensure_folder_exists_for (filename : string) : unit =
  let rec mkdir_p dir =
    if dir = Filename.current_dir_name || dir = Filename.parent_dir_name then ()
    else if Sys.file_exists dir then
      if Sys.is_directory dir then ()
      else failwith (dir ^ " exists but is not a directory")
    else (
      mkdir_p (Filename.dirname dir);
      Unix.mkdir dir 0o755)
  in
  let dir = Filename.dirname filename in
  mkdir_p dir
