#!/bin/bash
#-------------------------------------------------------------------------------------------------------------
# The random_minting.sh script scans the wallet every 5 mins to retrieve all the valid tx
# If supposes only 1 NFT is minted at a time, no multiples supported in the script
# So for a 0.1 xch mint it will filter only the 0.1 xch tx in the wallet

# known bug : the script will run properly if you already have at least 1 valid TX in your wallet, I need to implement that check for first run

FINGERPRINT=
WALLETID=
ROYALTIESADDY=
ROYALTIESPERC=
COLLECTION_SIZE=1000
FEE=0.000615 # max fee if mempool is full, otherwise you can put 0
AMOUNT=100000000000 # 0.1 xch
LU= # licence link
LH= # licence hash

#source the NFT.storage API key
source ./api_keys.txt

# this function is checking the current mint is over before proceeding to the next in order to avoid "change" problems in your wallet
check_pending_coin_removal() {
MINT_STATE=$(chia rpc wallet get_wallet_balance '{"wallet_id": 1}' | jq '.wallet_balance.pending_coin_removal_count')
while [ "$MINT_STATE" -ne 0 ]; do
	sleep 15
	MINT_STATE=$(chia rpc wallet get_wallet_balance '{"wallet_id": 1}' | jq '.wallet_balance.pending_coin_removal_count')
done	
}

while :
do
	source ./last_confirmed_height.txt

	# get all of the xch transactions in a wallet/fingerprint
	# the wallet must be synced on that fingerprint
	TOTAL_TX=$(chia rpc wallet get_transaction_count '{"wallet_id": 1}' | jq '.count')
	chia rpc wallet get_transactions '{"wallet_id": 1,"start": 0,"end": '$TOTAL_TX',"reverse": true}' > TX_list.txt

	#---------------------------------------------------------------------------------------------------
	# Filter only valid tx since last scan, storing the tx_id and the parent_coin_info associated
	#---------------------------------------------------------------------------------------------------
	cat TX_list.txt | jq '.transactions | .[] |select((.amount == '$AMOUNT') and .confirmed_at_height > '$LAST_CONFIRMED_HEIGHT' and .confirmed == 'true') | .name + "-" + (.additions | .[0].parent_coin_info)' > valid_list.txt
	CURRENT_LAST_CONFIRMED_HEIGHT=$(cat TX_list.txt | jq '.transactions | .[] |select((.amount == '$AMOUNT') and .confirmed_at_height >= '$LAST_CONFIRMED_HEIGHT' and .confirmed == 'true') | .confirmed_at_height' | head -n1)

	if [ "$LAST_CONFIRMED_HEIGHT" == "$CURRENT_LAST_CONFIRMED_HEIGHT" ]
	then
		echo "next run in 5 minutes"
		sleep 300
	else
	#---------------------------------------------------------------------------------------------------
		for i in $(cat valid_list.txt)
		do
			source ./nft_number.txt
			TX_ID_HASH=$(echo $i | cut -d '-' -f1 | cut -d '"' -f2 | cut -d 'x' -f 2)
			PARENT_COIN_INFO=$(echo $i | cut -d '-' -f2 | cut -d '"' -f1)

			if [ "$NFTNUMBER" == "$COLLECTION_SIZE" ]
			then
				# send xch back
				SENDER_ADDY_BECH32M=$(curl -s --insecure --cert ~/.chia/mainnet/config/ssl/full_node/private_full_node.crt --key ~/.chia/mainnet/config/ssl/full_node/private_full_node.key -d '{"name": "'$PARENT_COIN_INFO'"}' -H "Content-Type: application/json" -X POST https://localhost:8555/get_coin_record_by_name | jq '.coin_record.coin.puzzle_hash' | cut -d '"' -f2)
				SENDER_ADDY_XCH=$(~/chiadevtools/venv/bin/cdv encode -p xch $SENDER_ADDY_BECH32M)

				chia wallet send -f $FINGERPRINT -a 0.1 -t $SENDER_ADDY_XCH

				check_pending_coin_removal
			else
				# mint NFT
				LAST_CHARACTER=$(echo $TX_ID_HASH | cut -c64)
				BASE_SVG=Peacock

				# echo "$TX_ID_HASH - $PARENT_COIN_INFO"

				#---------------------------------------------------------------------------------------------------
				# Get parent_coin_info puzzle_hash, and translate it to XCH address => we obtain the sender address
				#---------------------------------------------------------------------------------------------------
				SENDER_ADDY_BECH32M=$(curl -s --insecure --cert ~/.chia/mainnet/config/ssl/full_node/private_full_node.crt --key ~/.chia/mainnet/config/ssl/full_node/private_full_node.key -d '{"name": "'$PARENT_COIN_INFO'"}' -H "Content-Type: application/json" -X POST https://localhost:8555/get_coin_record_by_name | jq '.coin_record.coin.puzzle_hash' | cut -d '"' -f2)
				SENDER_ADDY_XCH=$(~/chiadevtools/venv/bin/cdv encode -p xch $SENDER_ADDY_BECH32M)

				#---------------------------------------------------------------------------------------------------
				# Check if last character is equal to F and create PNG & JSON accordingly
				#---------------------------------------------------------------------------------------------------
				if [ "$LAST_CHARACTER" == "f" ]
				then
					DIGITS_TX_ID_HASH=$(echo $TX_ID_HASH | tr -cd '[[:digit:]]')
					RGB=1529
					SAMPLE_REJECTION=$((1+(9999/$RGB)*$RGB))
					VALID_NUMBER=false
					j=1
					while [ "$VALID_NUMBER" != "true" ]; do
						SEED=$(echo $DIGITS_TX_ID_HASH | cut -c$(($j+1))-$(($j+4)) | sed 's/^0*//')
						if [ $SEED -lt "$SAMPLE_REJECTION" ]
						then
							SEED_SR=$(($SEED%$RGB))
							VALID_NUMBER=true
						else
							((j++))
						fi
					done
					INDEX="$j-$(($j+3))"

					# create PNG
					./peacock_custom.sh $SEED_SR $NFTNUMBER
					NFT="Peacock_$NFTNUMBER"

					# create JSON
					cp Peacock_custom.json $NFT.json
					sed -i 's/NFT_NUMBER/'$NFTNUMBER'/g'  $NFT.json
					sed -i 's/SEED_4/'$SEED'/g'  $NFT.json
					sed -i 's/SEED_SR/'$SEED_SR'/g'  $NFT.json
					sed -i 's/INDEX/'$INDEX'/g'  $NFT.json
					sed -i 's/ITERATIONS/'$(($j-1))'/g'  $NFT.json
					sed -i 's/TX_ID_HASH/'$TX_ID_HASH'/g'  $NFT.json
				else
					# create PNG
					NFT="Peacock_$NFTNUMBER"

					COLOR1=$(echo $TX_ID_HASH | cut -c1-6)
					COLOR2=$(echo $TX_ID_HASH | cut -c7-12)
					COLOR3=$(echo $TX_ID_HASH | cut -c13-18)
					COLOR4=$(echo $TX_ID_HASH | cut -c19-24)
					COLOR5=$(echo $TX_ID_HASH | cut -c25-30)

					cp $BASE_SVG.svg $NFT.svg
					sed -i 's/COLOR1/'$COLOR1'/g'  $NFT.svg
					sed -i 's/COLOR2/'$COLOR2'/g'  $NFT.svg
					sed -i 's/COLOR3/'$COLOR3'/g'  $NFT.svg
					sed -i 's/COLOR4/'$COLOR4'/g'  $NFT.svg
					sed -i 's/COLOR5/'$COLOR5'/g'  $NFT.svg

					convert $NFT.svg -rotate 270 -crop 3500x2000+270+1020 $NFT.png

					# create JSON
					cp Peacock_regular.json $NFT.json
					sed -i 's/COLOR1/'$COLOR1'/g'  $NFT.json
					sed -i 's/COLOR2/'$COLOR2'/g'  $NFT.json
					sed -i 's/COLOR3/'$COLOR3'/g'  $NFT.json
					sed -i 's/COLOR4/'$COLOR4'/g'  $NFT.json
					sed -i 's/COLOR5/'$COLOR5'/g'  $NFT.json
					sed -i 's/NFT_NUMBER/'$NFTNUMBER'/g'  $NFT.json
					sed -i 's/TX_ID_HASH/'$TX_ID_HASH'/g'  $NFT.json
				fi

				#---------------------------------------------------------------------------------------------------
				# NFT.STORAGE pin
				#---------------------------------------------------------------------------------------------------

				PNG_CID=$(curl -X 'POST' 'https://api.nft.storage/upload' -H 'accept: application/json' -H 'Content-Type: image/*' --header 'Authorization: Bearer '$API_KEY'' --data-binary '@'$NFT'.png' | jq -r '.value.cid')
				JSON_CID=$(curl -X 'POST' 'https://api.nft.storage/upload' -H 'accept: application/json' -H 'Content-Type: image/*' --header 'Authorization: Bearer '$API_KEY'' --data-binary '@'$NFT'.json' | jq -r '.value.cid')
				NU=$(echo "https://$PNG_CID.ipfs.nftstorage.link")
				MU=$(echo "https://$JSON_CID.ipfs.nftstorage.link")
				NH=$(curl -s $NU | sha256sum | cut -d ' ' -f 1)
				MH=$(curl -s $MU | sha256sum | cut -d ' ' -f 1)

				#---------------------------------------------------------------------------------------------------
				# Mint
				#---------------------------------------------------------------------------------------------------
				chia wallet nft mint -f $FINGERPRINT -i $WALLETID -ra $ROYALTIESADDY -rp $ROYALTIESPERC -m $FEE -ta $SENDER_ADDY_XCH -lu $LU -lh $LH -nh $NH -u $NU -mh $MH -mu $MU

				check_pending_coin_removal

				echo "NFTNUMBER=$(($NFTNUMBER+1))" > nft_number.txt
				mv $NFT.json minted/
				mv $NFT.png minted/
				mv $NFT.svg minted/
			fi
		done
	fi
	echo "LAST_CONFIRMED_HEIGHT=$CURRENT_LAST_CONFIRMED_HEIGHT" > last_confirmed_height.txt
	mv valid_list.txt minted/valid_list_$CURRENT_LAST_CONFIRMED_HEIGHT.txt
done