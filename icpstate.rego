package icp.state

import data.nodes
import data.syspods

IMAGES_SIZE_TH = 3e+10  

# Policy #1: Look for any kublet which is not the latest version. Useful for checking if any upgrades didn't occur
any_kubelets_not_matching_version {
  n = nodes.items[_]
  not startswith(n.status.nodeInfo.kubeletVersion, "v1.8.3")
}

all_kubelets_match_version {
  not any_kubelets_not_matching_version
}


# Policy #2: Check for system pods which are in a not ready state
any_pods_not_ready {
  status = syspods.items[_].status.containerStatuses[_]
  not status.ready = true
}

all_pods_ready {
  not any_pods_not_ready
}

sys_pods_not_ready [[name]] {
     status = syspods.items[_].status.containerStatuses[_]
     not status.ready =true
     not status.state.terminated.reason="Completed"
     name=status.name
}

# Policy #3: Check for any nodes which have conditions (e.g MemoryPressure)
any_nodes_not_ready {
  n = nodes.items[_].status.conditions
  n[i].type = "Ready"
  n[i].status != "True"
}

all_nodes_ready {
  not any_nodes_not_ready
}

any_node_with_cond {
  n = nodes.items[_].status.conditions
  n[i].type != "Ready"
  n[i].status = "True"
}


# Policy #4: Check for nodes where the total size of all images is greater than a threshold
big_images_size_nodes [[name, s]] {
     node = nodes.items[_]
     sum([i | i = node.status.images[_].sizeBytes], s)
    s > IMAGES_SIZE_TH
    name = node.metadata.name
}


check_images_size = check_cache {
         input.maxsize > IMAGES_SIZE_TH
   } else = check_data {
         input.maxsize < IMAGES_SIZE_TH 
   } else =  big_images_size_nodes{
        input.maxsize = IMAGES_SIZE_TH
} 

# get from cache
check_cache[node] {
    node = big_images_size_nodes[_]
    node[1] > input.maxsize
}

check_data[[nodeName, s]] {
   node = nodes.items[_]
   sum([i | i = node.status.images[_].sizeBytes], s)
   s > input.maxsize
   nodeName = node.metadata.name
}


